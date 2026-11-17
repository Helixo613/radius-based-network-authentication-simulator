import { useState } from 'react';
import { useLogin, useNotify, useTranslate } from 'react-admin';
import { useQueryClient } from '@tanstack/react-query';
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  InputAdornment,
  IconButton,
  CircularProgress,
} from '@mui/material';
import { Visibility, VisibilityOff, Person, Lock } from '@mui/icons-material';

export const LoginPage = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const login = useLogin();
  const notify = useNotify();
  const translate = useTranslate();
  const queryClient = useQueryClient();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!username || !password) {
      notify(translate('validation.required'), { type: 'warning' });
      return;
    }

    setLoading(true);
    try {
      await login({ username, password });
      // Ensure AppBar UserMenu picks up the newly stored identity.
      await queryClient.invalidateQueries({ queryKey: ['auth', 'getIdentity'] });
      await queryClient.invalidateQueries({ queryKey: ['auth', 'getPermissions'] });
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : translate('auth.login_error');
      notify(errorMessage, { type: 'error' });
      setLoading(false);
    }
  };

  return (
    <Box
      sx={{
        display: 'flex',
        minHeight: '100vh',
        alignItems: 'center',
        justifyContent: 'center',
        p: 2,
        background: 'radial-gradient(circle at 20% 20%, #134e4a 0%, #0f172a 70%)',
      }}
    >
      <Card sx={{ display: 'flex', flexDirection: { xs: 'column', md: 'row' }, maxWidth: 920, width: '100%', borderRadius: 3, boxShadow: 6, overflow: 'hidden' }}>
        <Box
          sx={{
            flex: 1,
            p: { xs: 4, md: 5 },
            color: '#f0fdfa',
            background: 'linear-gradient(160deg, #0f766e 0%, #134e4a 100%)',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <Box component="img" src="/admin/logo.svg" alt="" sx={{ width: 56, height: 56, mb: 2 }} />
          <Typography variant="h5" sx={{ fontWeight: 700, lineHeight: 1.25, mb: 1 }}>
            {translate('app.title')}
          </Typography>
          <Typography variant="body2" sx={{ opacity: 0.85, mb: 3 }}>
            {translate('app.subtitle')}
          </Typography>
          <Box component="ul" sx={{ pl: 2.5, m: 0, '& li': { mb: 1, fontSize: 14, opacity: 0.9 } }}>
            <li>RADIUS server: authentication (RFC 2865) and accounting (RFC 2866)</li>
            <li>Built-in NAS simulator: send real RADIUS packets from the browser</li>
            <li>802.1X / EAP methods, RadSec, live sessions and accounting logs</li>
          </Box>
          <Box sx={{ flexGrow: 1 }} />
          <Typography variant="caption" sx={{ mt: 4, opacity: 0.8 }}>
            Developed by <strong>Kushagra Sachdeva</strong> · {new Date().getFullYear()}
          </Typography>
        </Box>

        <CardContent sx={{ flex: 1, p: { xs: 4, md: 5 }, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
          <Typography variant="h5" sx={{ fontWeight: 700, mb: 0.5 }}>
            {translate('auth.welcome')}
          </Typography>
          <Typography variant="body2" sx={{ color: 'text.secondary', mb: 4 }}>
            Sign in to the admin console
          </Typography>

          <form onSubmit={handleSubmit}>
            <Box sx={{ mb: 3 }}>
              <TextField
                fullWidth
                label={translate('auth.username')}
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                disabled={loading}
                autoFocus
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <Person color="action" />
                    </InputAdornment>
                  ),
                }}
              />
            </Box>

            <Box sx={{ mb: 3 }}>
              <TextField
                fullWidth
                label={translate('auth.password')}
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={loading}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <Lock color="action" />
                    </InputAdornment>
                  ),
                  endAdornment: (
                    <InputAdornment position="end">
                      <IconButton
                        onClick={() => setShowPassword(!showPassword)}
                        edge="end"
                        disabled={loading}
                      >
                        {showPassword ? <VisibilityOff /> : <Visibility />}
                      </IconButton>
                    </InputAdornment>
                  ),
                }}
              />
            </Box>

            <Button
              type="submit"
              fullWidth
              variant="contained"
              size="large"
              disabled={loading}
              sx={{
                mt: 2,
                py: 1.5,
                background: 'linear-gradient(135deg, #0f766e 0%, #115e59 100%)',
                '&:hover': {
                  background: 'linear-gradient(135deg, #115e59 0%, #134e4a 100%)',
                },
              }}
            >
              {loading ? (
                <CircularProgress size={24} color="inherit" />
              ) : (
                translate('auth.sign_in')
              )}
            </Button>
          </form>
        </CardContent>
      </Card>
    </Box>
  );
};
