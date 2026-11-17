package adminapi

import (
	"encoding/json"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/require"
	"github.com/talkincode/toughradius/v9/internal/domain"
	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
	"layeh.com/radius/rfc2866"
)

// startFakeRadius answers Access-Request with Accept only for password "good",
// and every Accounting-Request with Accounting-Response. It records status types.
func startFakeRadius(t *testing.T, secret string) (int, *[]string) {
	t.Helper()
	conn, err := net.ListenPacket("udp", "127.0.0.1:0")
	require.NoError(t, err)
	var mu sync.Mutex
	seen := []string{}
	srv := &radius.PacketServer{
		SecretSource: radius.StaticSecretSource([]byte(secret)),
		Handler: radius.HandlerFunc(func(w radius.ResponseWriter, r *radius.Request) {
			mu.Lock()
			defer mu.Unlock()
			if r.Code == radius.CodeAccessRequest {
				seen = append(seen, "auth:"+rfc2865.NASIdentifier_GetString(r.Packet))
				code := radius.CodeAccessReject
				if rfc2865.UserPassword_GetString(r.Packet) == "good" {
					code = radius.CodeAccessAccept
				}
				_ = w.Write(r.Response(code))
				return
			}
			seen = append(seen, rfc2866.AcctStatusType_Get(r.Packet).String())
			_ = w.Write(r.Response(radius.CodeAccountingResponse))
		}),
	}
	go func() { _ = srv.Serve(conn) }()
	t.Cleanup(func() { _ = conn.Close() })
	return conn.LocalAddr().(*net.UDPAddr).Port, &seen
}

func runSimRequest(t *testing.T, body string, port int) (*httptest.ResponseRecorder, simResult) {
	t.Helper()
	db := setupTestDB(t)
	appCtx := setupTestApp(t, db)
	appCtx.Config().Radiusd.AuthPort = port
	appCtx.Config().Radiusd.AcctPort = port
	require.NoError(t, db.Create(&domain.NetNas{ID: 7, Name: "lab-ap", Identifier: "lab-ap", Ipaddr: "10.1.1.1", Secret: "s3cret"}).Error)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/simulator/run", strings.NewReader(body))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	require.NoError(t, runSimulation(CreateTestContext(setupTestEcho(), db, req, rec, appCtx)))

	var resp Response
	var result simResult
	if rec.Code == http.StatusOK {
		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
		raw, _ := json.Marshal(resp.Data)
		require.NoError(t, json.Unmarshal(raw, &result))
	}
	return rec, result
}

func TestSimulatorFullSession(t *testing.T) {
	port, seen := startFakeRadius(t, "s3cret")
	rec, res := runSimRequest(t, `{"nas_id":"7","username":"alice","password":"good","mode":"session"}`, port)
	require.Equal(t, http.StatusOK, rec.Code)
	require.Len(t, res.Steps, 4)
	for _, s := range res.Steps {
		require.True(t, s.Success, s.Name)
	}
	require.Equal(t, "Access-Accept", res.Steps[0].ResponseCode)
	require.Equal(t, []string{"auth:lab-ap", "Start", "Interim-Update", "Stop"}, *seen)
	for _, a := range res.Steps[0].RequestAttrs {
		if a.Name == "UserPassword" {
			require.Equal(t, "******", a.Value)
		}
	}
}

func TestSimulatorRejectStopsFlow(t *testing.T) {
	port, seen := startFakeRadius(t, "s3cret")
	_, res := runSimRequest(t, `{"nas_id":"7","username":"alice","password":"bad","mode":"session"}`, port)
	require.Len(t, res.Steps, 1)
	require.False(t, res.Steps[0].Success)
	require.Equal(t, "Access-Reject", res.Steps[0].ResponseCode)
	require.Len(t, *seen, 1)
}

func TestSimulatorValidation(t *testing.T) {
	port, _ := startFakeRadius(t, "s3cret")
	cases := map[string]int{
		`{"nas_id":"7","username":"a","password":"b","mode":"bogus"}`: http.StatusBadRequest,
		`{"nas_id":"7","username":"","password":"b"}`:                 http.StatusBadRequest,
		`{"nas_id":"999","username":"a","password":"b"}`:              http.StatusNotFound,
	}
	for body, want := range cases {
		rec, _ := runSimRequest(t, body, port)
		require.Equal(t, want, rec.Code, body+" -> "+strconv.Itoa(rec.Code))
	}
}
