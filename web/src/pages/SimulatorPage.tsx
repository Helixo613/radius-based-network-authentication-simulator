import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Title, useGetList, useNotify } from 'react-admin';
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  MenuItem,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableRow,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material';
import PlayArrowRoundedIcon from '@mui/icons-material/PlayArrowRounded';
import LaptopMacOutlinedIcon from '@mui/icons-material/LaptopMacOutlined';
import RouterOutlinedIcon from '@mui/icons-material/RouterOutlined';
import DnsOutlinedIcon from '@mui/icons-material/DnsOutlined';
import ArrowForwardRoundedIcon from '@mui/icons-material/ArrowForwardRounded';
import { extractData, httpClient } from '../utils/apiClient';

type Mode = 'auth' | 'login' | 'session';

interface SimAttr {
  name: string;
  value: string;
}

interface SimStep {
  name: string;
  request_code: string;
  response_code: string;
  success: boolean;
  rtt_ms: number;
  request_attrs: SimAttr[];
  response_attrs: SimAttr[] | null;
  error?: string;
}

interface SimResult {
  session_id: string;
  mode: Mode;
  steps: SimStep[];
}

const MODES: { value: Mode; label: string; help: string }[] = [
  { value: 'auth', label: 'Authenticate', help: 'Send one Access-Request and see whether the server accepts the credentials.' },
  { value: 'login', label: 'Log in', help: 'Authenticate, then send Accounting-Start. The user stays online until you disconnect them.' },
  { value: 'session', label: 'Full session', help: 'Authenticate, then Accounting Start, Interim-Update and Stop: a complete connect-to-disconnect cycle.' },
];

const FlowNode = ({ icon, label, sub }: { icon: React.ReactNode; label: string; sub: string }) => (
  <Stack alignItems="center" spacing={0.5} sx={{ minWidth: 120 }}>
    <Box sx={{ p: 1.5, borderRadius: '50%', bgcolor: 'primary.main', color: 'primary.contrastText', display: 'flex' }}>{icon}</Box>
    <Typography variant="subtitle2">{label}</Typography>
    <Typography variant="caption" color="text.secondary">{sub}</Typography>
  </Stack>
);

const AttrTable = ({ title, attrs }: { title: string; attrs: SimAttr[] | null }) => (
  <Box sx={{ flex: 1, minWidth: 260 }}>
    <Typography variant="overline" color="text.secondary">{title}</Typography>
    {attrs && attrs.length > 0 ? (
      <Table size="small">
        <TableBody>
          {attrs.map((a, i) => (
            <TableRow key={`${a.name}-${i}`}>
              <TableCell sx={{ fontFamily: 'monospace', color: 'text.secondary', width: '45%' }}>{a.name}</TableCell>
              <TableCell sx={{ fontFamily: 'monospace', wordBreak: 'break-all' }}>{a.value}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    ) : (
      <Typography variant="body2" color="text.secondary">No attributes</Typography>
    )}
  </Box>
);

const StepCard = ({ step, index }: { step: SimStep; index: number }) => {
  const color = step.error ? 'default' : step.success ? 'success' : 'error';
  return (
    <Card variant="outlined" sx={{ borderLeft: 4, borderLeftColor: `${color === 'default' ? 'grey' : color}.main` }}>
      <CardContent>
        <Stack direction="row" alignItems="center" spacing={1.5} flexWrap="wrap" sx={{ mb: 1 }}>
          <Typography variant="h6">{index + 1}. {step.name}</Typography>
          <Chip size="small" label={step.request_code} variant="outlined" />
          <ArrowForwardRoundedIcon fontSize="small" color="action" />
          <Chip size="small" color={color} label={step.error ? 'No response' : step.response_code} />
          <Typography variant="body2" color="text.secondary">{step.rtt_ms.toFixed(2)} ms</Typography>
        </Stack>
        {step.error && <Alert severity="warning" sx={{ mb: 1 }}>{step.error}</Alert>}
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={3}>
          <AttrTable title="Request sent by NAS" attrs={step.request_attrs} />
          <AttrTable title="Server response" attrs={step.response_attrs} />
        </Stack>
      </CardContent>
    </Card>
  );
};

export const SimulatorPage = () => {
  const notify = useNotify();
  const { data: nasList = [], isPending: nasLoading } = useGetList('network/nas', {
    pagination: { page: 1, perPage: 100 },
    sort: { field: 'name', order: 'ASC' },
  });
  const { data: users = [] } = useGetList('radius/users', {
    pagination: { page: 1, perPage: 200 },
    sort: { field: 'username', order: 'ASC' },
  });

  const [nasId, setNasId] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [mode, setMode] = useState<Mode>('auth');
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState<SimResult | null>(null);

  const selectedNas = nasId || (nasList[0] ? String(nasList[0].id) : '');

  const run = async () => {
    setRunning(true);
    setResult(null);
    try {
      const { json } = await httpClient('/simulator/run', {
        method: 'POST',
        body: JSON.stringify({ nas_id: selectedNas, username, password, mode }),
      });
      setResult(extractData<SimResult>(json));
    } catch (error) {
      notify(error instanceof Error ? error.message : 'Simulation failed', { type: 'error' });
    } finally {
      setRunning(false);
    }
  };

  const allPassed = result?.steps.every((s) => s.success);

  return (
    <Box sx={{ p: { xs: 1, md: 3 } }}>
      <Title title="Simulator" />
      <Typography variant="h4" gutterBottom>RADIUS Authentication Simulator</Typography>
      <Typography color="text.secondary" sx={{ mb: 3, maxWidth: 820 }}>
        Act as a network access device (a Wi-Fi access point, VPN gateway or switch) and send real RADIUS
        packets to this server. Each exchange below shows the attributes on the wire and the server&apos;s decision.
      </Typography>

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Stack direction="row" justifyContent="center" alignItems="center" spacing={2} flexWrap="wrap" sx={{ mb: 3 }}>
            <FlowNode icon={<LaptopMacOutlinedIcon />} label="User device" sub={username || 'username + password'} />
            <ArrowForwardRoundedIcon color="action" />
            <FlowNode icon={<RouterOutlinedIcon />} label="NAS (simulated)" sub={nasList.find((n) => String(n.id) === selectedNas)?.name ?? 'choose below'} />
            <ArrowForwardRoundedIcon color="action" />
            <FlowNode icon={<DnsOutlinedIcon />} label="RADIUS server" sub="UDP 1812 / 1813" />
          </Stack>

          <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} sx={{ mb: 2 }}>
            <TextField
              select
              label="NAS device"
              value={selectedNas}
              onChange={(e) => setNasId(e.target.value)}
              disabled={nasLoading || nasList.length === 0}
              helperText={nasList.length === 0 && !nasLoading ? 'Add a NAS device first' : 'Packets are signed with this NAS secret'}
              sx={{ minWidth: 220 }}
            >
              {nasList.map((n) => (
                <MenuItem key={n.id} value={String(n.id)}>{n.name} ({n.ipaddr})</MenuItem>
              ))}
            </TextField>
            <Autocomplete
              freeSolo
              options={users.map((u) => String(u.username))}
              inputValue={username}
              onInputChange={(_, v) => setUsername(v)}
              sx={{ minWidth: 220, flex: 1 }}
              renderInput={(params) => <TextField {...params} label="Username" />}
            />
            <TextField
              label="Password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && username && password && !running && run()}
              sx={{ minWidth: 220, flex: 1 }}
            />
          </Stack>

          <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} alignItems={{ md: 'center' }}>
            <ToggleButtonGroup exclusive size="small" value={mode} onChange={(_, v) => v && setMode(v)}>
              {MODES.map((m) => <ToggleButton key={m.value} value={m.value}>{m.label}</ToggleButton>)}
            </ToggleButtonGroup>
            <Typography variant="body2" color="text.secondary" sx={{ flex: 1 }}>
              {MODES.find((m) => m.value === mode)?.help}
            </Typography>
            <Button
              variant="contained"
              size="large"
              startIcon={running ? <CircularProgress size={18} color="inherit" /> : <PlayArrowRoundedIcon />}
              disabled={running || !selectedNas || !username || !password}
              onClick={run}
            >
              Run simulation
            </Button>
          </Stack>
        </CardContent>
      </Card>

      {result && (
        <Stack spacing={2}>
          <Alert severity={allPassed ? 'success' : 'error'}>
            {allPassed
              ? `Simulation completed: ${result.steps.length} exchange(s) succeeded.`
              : 'The server rejected the request or did not respond. See the step details below.'}
            {allPassed && result.mode === 'login' && (
              <> The user is now online: see <Link to="/radius/online">Online Sessions</Link>.</>
            )}
            {allPassed && result.mode === 'session' && (
              <> The session was recorded: see <Link to="/radius/accounting">Accounting Logs</Link>.</>
            )}
          </Alert>
          {result.steps.map((step, i) => <StepCard key={step.name} step={step} index={i} />)}
        </Stack>
      )}
    </Box>
  );
};

export default SimulatorPage;
