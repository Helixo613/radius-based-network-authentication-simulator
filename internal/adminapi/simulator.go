package adminapi

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/talkincode/toughradius/v9/internal/domain"
	"github.com/talkincode/toughradius/v9/internal/radiusd"
	"github.com/talkincode/toughradius/v9/internal/webserver"
	"gorm.io/gorm"
	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
	"layeh.com/radius/rfc2866"
)

// The simulator plays the role of a NAS (Wi-Fi AP, VPN gateway, BRAS): it sends
// real RADIUS packets to this server's own auth/acct ports, signed with the
// chosen NAS's shared secret, and reports every exchange back to the web UI.

const simulatorTimeout = 3 * time.Second

// Simulation modes.
const (
	simModeAuth    = "auth"    // Access-Request only
	simModeLogin   = "login"   // Access-Request + Accounting-Start (user stays online)
	simModeSession = "session" // Access-Request + Start + Interim-Update + Stop
)

type simulatorRequest struct {
	NasID    string `json:"nas_id"`
	Username string `json:"username"`
	Password string `json:"password"`
	Mode     string `json:"mode"`
}

type simAttr struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

type simStep struct {
	Name          string    `json:"name"`
	RequestCode   string    `json:"request_code"`
	ResponseCode  string    `json:"response_code"`
	Success       bool      `json:"success"`
	RttMs         float64   `json:"rtt_ms"`
	RequestAttrs  []simAttr `json:"request_attrs"`
	ResponseAttrs []simAttr `json:"response_attrs"`
	Error         string    `json:"error,omitempty"`
}

type simResult struct {
	SessionID string    `json:"session_id"`
	Mode      string    `json:"mode"`
	Steps     []simStep `json:"steps"`
}

func registerSimulatorRoutes() {
	webserver.ApiPOST("/simulator/run", runSimulation, requireAdmin())
}

func runSimulation(c echo.Context) error {
	var req simulatorRequest
	if err := c.Bind(&req); err != nil {
		return fail(c, http.StatusBadRequest, "INVALID_REQUEST", "Invalid request body", err.Error())
	}
	req.Username = strings.TrimSpace(req.Username)
	if req.Mode == "" {
		req.Mode = simModeAuth
	}
	if req.Mode != simModeAuth && req.Mode != simModeLogin && req.Mode != simModeSession {
		return fail(c, http.StatusBadRequest, "INVALID_MODE", "Mode must be auth, login or session", nil)
	}
	if req.Username == "" || req.Password == "" {
		return fail(c, http.StatusBadRequest, "MISSING_CREDENTIALS", "Username and password are required", nil)
	}
	nasID, err := strconv.ParseInt(req.NasID, 10, 64)
	if err != nil {
		return fail(c, http.StatusBadRequest, "INVALID_NAS", "Choose a NAS device", nil)
	}
	var nas domain.NetNas
	if err := GetDB(c).First(&nas, nasID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fail(c, http.StatusNotFound, "NAS_NOT_FOUND", "NAS device not found", nil)
		}
		return fail(c, http.StatusInternalServerError, "DATABASE_ERROR", "Failed to load NAS device", err.Error())
	}

	cfg := GetAppContext(c).Config()
	sim := &nasSimulator{
		nas:       nas,
		username:  req.Username,
		mac:       randomMAC(),
		sessionID: uuid.NewString(),
		authAddr:  net.JoinHostPort("127.0.0.1", strconv.Itoa(cfg.Radiusd.AuthPort)),
		acctAddr:  net.JoinHostPort("127.0.0.1", strconv.Itoa(cfg.Radiusd.AcctPort)),
	}
	return ok(c, simResult{SessionID: sim.sessionID, Mode: req.Mode, Steps: sim.run(req.Mode, req.Password)})
}

// acctStep is one simulated accounting packet: elapsed seconds and bytes downloaded so far.
type acctStep struct {
	name   string
	status rfc2866.AcctStatusType
	secs   uint32
	bytes  uint32
}

type nasSimulator struct {
	nas       domain.NetNas
	username  string
	mac       string
	sessionID string
	authAddr  string
	acctAddr  string
}

// run performs the exchanges for a mode, stopping at the first failed step.
func (s *nasSimulator) run(mode, password string) []simStep {
	auth := s.newPacket(radius.CodeAccessRequest)
	_ = rfc2865.UserPassword_SetString(auth, password)
	step, resp := s.exchange("Authentication", auth, s.authAddr, radius.CodeAccessAccept)
	steps := []simStep{step}
	if mode == simModeAuth || !step.Success {
		return steps
	}

	framedIP := rfc2865.FramedIPAddress_Get(resp)
	acct := []acctStep{{"Accounting Start", rfc2866.AcctStatusType_Value_Start, 0, 0}}
	if mode == simModeSession {
		acct = append(acct,
			acctStep{"Accounting Interim-Update", rfc2866.AcctStatusType_Value_InterimUpdate, 60, 5 << 20},
			acctStep{"Accounting Stop", rfc2866.AcctStatusType_Value_Stop, 120, 12 << 20},
		)
	}
	for _, a := range acct {
		pkt := s.newPacket(radius.CodeAccountingRequest)
		_ = rfc2866.AcctStatusType_Set(pkt, a.status)
		_ = rfc2866.AcctSessionID_SetString(pkt, s.sessionID)
		_ = rfc2866.AcctSessionTime_Set(pkt, rfc2866.AcctSessionTime(a.secs))
		_ = rfc2866.AcctInputOctets_Set(pkt, rfc2866.AcctInputOctets(a.bytes/4))
		_ = rfc2866.AcctOutputOctets_Set(pkt, rfc2866.AcctOutputOctets(a.bytes))
		if framedIP != nil {
			_ = rfc2865.FramedIPAddress_Set(pkt, framedIP)
		}
		if a.status == rfc2866.AcctStatusType_Value_Stop {
			_ = rfc2866.AcctTerminateCause_Set(pkt, rfc2866.AcctTerminateCause_Value_UserRequest)
		}
		step, _ := s.exchange(a.name, pkt, s.acctAddr, radius.CodeAccountingResponse)
		steps = append(steps, step)
		if !step.Success {
			break
		}
	}
	return steps
}

// newPacket builds a request carrying the attributes a real NAS sends.
// NAS-Identifier lets the server find the NAS even though packets come from 127.0.0.1.
func (s *nasSimulator) newPacket(code radius.Code) *radius.Packet {
	pkt := radius.New(code, []byte(s.nas.Secret))
	_ = rfc2865.UserName_SetString(pkt, s.username)
	if s.nas.Identifier != "" {
		_ = rfc2865.NASIdentifier_SetString(pkt, s.nas.Identifier)
	}
	if ip := net.ParseIP(s.nas.Ipaddr).To4(); ip != nil {
		_ = rfc2865.NASIPAddress_Set(pkt, ip)
	}
	_ = rfc2865.NASPort_Set(pkt, 1)
	_ = rfc2865.NASPortType_Set(pkt, rfc2865.NASPortType_Value_Wireless80211)
	_ = rfc2865.CallingStationID_SetString(pkt, s.mac)
	_ = rfc2865.CalledStationID_SetString(pkt, "SIMULATOR-AP")
	return pkt
}

func (s *nasSimulator) exchange(name string, pkt *radius.Packet, addr string, want radius.Code) (simStep, *radius.Packet) {
	step := simStep{Name: name, RequestCode: pkt.Code.String(), RequestAttrs: packetAttrs(pkt)}
	ctx, cancel := context.WithTimeout(context.Background(), simulatorTimeout)
	defer cancel()
	start := time.Now()
	resp, err := (&radius.Client{Retry: 0}).Exchange(ctx, pkt, addr)
	step.RttMs = float64(time.Since(start).Microseconds()) / 1000
	if err != nil {
		step.Error = simErrorText(err)
		return step, nil
	}
	step.ResponseCode = resp.Code.String()
	step.ResponseAttrs = packetAttrs(resp)
	step.Success = resp.Code == want
	return step, resp
}

func simErrorText(err error) string {
	if errors.Is(err, context.DeadlineExceeded) {
		return "No response within 3s. Is the RADIUS server running, and is the NAS secret correct?"
	}
	return err.Error()
}

// packetAttrs lists attributes in readable form, hiding the password.
func packetAttrs(p *radius.Packet) []simAttr {
	attrs := make([]simAttr, 0, len(p.Attributes))
	for _, a := range p.Attributes {
		value := radiusd.FormatType(a.Type, a.Attribute)
		switch a.Type {
		case rfc2865.UserPassword_Type:
			value = "******"
		case rfc2865.VendorSpecific_Type:
			value = fmt.Sprintf("%x", []byte(a.Attribute))
		}
		attrs = append(attrs, simAttr{Name: radiusd.StringType(a.Type), Value: value})
	}
	return attrs
}

// randomMAC returns a locally administered unicast MAC, so each run looks like a new device.
func randomMAC() string {
	b := make([]byte, 6)
	_, _ = rand.Read(b)
	b[0] = (b[0] | 0x02) & 0xfe
	return fmt.Sprintf("%02X-%02X-%02X-%02X-%02X-%02X", b[0], b[1], b[2], b[3], b[4], b[5])
}
