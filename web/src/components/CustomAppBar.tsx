import SettingsOutlinedIcon from '@mui/icons-material/SettingsOutlined';
import AccountCircleOutlinedIcon from '@mui/icons-material/AccountCircleOutlined';
import MenuIcon from '@mui/icons-material/Menu';
import MenuOpenIcon from '@mui/icons-material/MenuOpen';
import { Box, IconButton, Stack, Tooltip, Typography, useTheme } from '@mui/material';
import { AppBar, AppBarProps, TitlePortal, ToggleThemeButton, useRedirect, useGetIdentity, useTranslate, useSidebarState } from 'react-admin';

export const CustomAppBar = (props: AppBarProps) => {
  const redirect = useRedirect();
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  const { data: identity } = useGetIdentity();
  const translate = useTranslate();
  const [sidebarOpen, setSidebarOpen] = useSidebarState();

  const handleToggleSidebar = () => {
    setSidebarOpen(!sidebarOpen);
  };

  return (
    <AppBar
      {...props}
      toolbar={false}
      elevation={0}
      alwaysOn={true}
      sx={{
        // Light theme uses a white background, dark theme a dark one
        backgroundColor: isDark ? '#1e293b' : '#ffffff',
        color: isDark ? '#f1f5f9' : '#1f2937',
        borderBottom: isDark 
          ? '1px solid rgba(148, 163, 184, 0.2)'
          : '1px solid rgba(229, 231, 235, 0.8)',
        boxShadow: isDark 
          ? 'none' 
          : '0 1px 3px 0 rgba(0, 0, 0, 0.05)',
        transition: 'all 0.3s ease',
        // Hide the default hamburger button; we add our own
        '& .RaAppBar-menuButton': {
          display: 'none',
        },
      }}
    >
      <TitlePortal />
      <Box
        sx={{
          width: '100%',
          px: 2,
          py: 0.5,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <Stack direction="row" spacing={1} alignItems="center">
          {/* Sidebar expand/collapse button */}
          <Tooltip title={sidebarOpen ? translate('appbar.collapse_menu') : translate('appbar.expand_menu')}>
            <IconButton 
              size="medium"
              onClick={handleToggleSidebar}
              sx={{
                color: isDark ? '#f1f5f9' : '#6b7280',
                transition: 'all 0.2s ease',
                '&:hover': {
                  backgroundColor: isDark 
                    ? 'rgba(255, 255, 255, 0.1)'
                    : 'rgba(0, 0, 0, 0.05)',
                },
              }}
            >
              {sidebarOpen ? <MenuOpenIcon /> : <MenuIcon />}
            </IconButton>
          </Tooltip>
          <Typography 
            variant="h6" 
            sx={{ 
              fontSize: 18, 
              fontWeight: 700, 
              color: isDark ? '#f1f5f9' : '#1f2937',
              letterSpacing: '0.5px',
            }}
          >
            RADIUS Auth Simulator
          </Typography>
        </Stack>

        <Stack direction="row" spacing={1} alignItems="center">
          <Tooltip title={translate('appbar.toggle_theme')}>
            <Box 
              sx={{ 
                '& svg': { 
                  fontSize: 22, 
                  color: isDark ? '#f1f5f9' : '#6b7280',
                },
                '& button': {
                  color: isDark ? '#f1f5f9' : '#6b7280',
                  transition: 'all 0.2s ease',
                  '&:hover': {
                    transform: 'rotate(180deg)',
                    backgroundColor: isDark 
                      ? 'rgba(255, 255, 255, 0.1)'
                      : 'rgba(0, 0, 0, 0.05)',
                  },
                },
              }}
            >
              <ToggleThemeButton />
            </Box>
          </Tooltip>
          
          {/* Show the system settings button only to super admins and admins */}
          {identity?.level === 'super' || identity?.level === 'admin' ? (
            <Tooltip title={translate('appbar.system_settings')}>
              <IconButton 
                size="large" 
                onClick={() => redirect('/system/config')}
                sx={{
                  color: isDark ? '#f1f5f9' : '#6b7280',
                  transition: 'all 0.2s ease',
                  '&:hover': {
                    transform: 'scale(1.05)',
                    backgroundColor: isDark 
                      ? 'rgba(255, 255, 255, 0.1)'
                      : 'rgba(0, 0, 0, 0.05)',
                  },
                }}
              >
                <SettingsOutlinedIcon />
              </IconButton>
            </Tooltip>
          ) : null}

          {/* Account settings button - visible to all users */}
          <Tooltip title={translate('appbar.account_settings')}>
            <IconButton 
              size="large" 
              onClick={() => redirect('/account/settings')}
              sx={{
                color: isDark ? '#f1f5f9' : '#6b7280',
                transition: 'all 0.2s ease',
                '&:hover': {
                  transform: 'scale(1.05)',
                  backgroundColor: isDark 
                    ? 'rgba(255, 255, 255, 0.1)'
                    : 'rgba(0, 0, 0, 0.05)',
                },
              }}
            >
              <AccountCircleOutlinedIcon />
            </IconButton>
          </Tooltip>
        </Stack>
      </Box>
    </AppBar>
  );
};
