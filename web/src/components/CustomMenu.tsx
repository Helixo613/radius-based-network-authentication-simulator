import DashboardOutlinedIcon from '@mui/icons-material/DashboardOutlined';
import PeopleAltOutlinedIcon from '@mui/icons-material/PeopleAltOutlined';
import SensorsOutlinedIcon from '@mui/icons-material/SensorsOutlined';
import ReceiptLongOutlinedIcon from '@mui/icons-material/ReceiptLongOutlined';
import SettingsSuggestOutlinedIcon from '@mui/icons-material/SettingsSuggestOutlined';
import SettingsOutlinedIcon from '@mui/icons-material/SettingsOutlined';
import RouterOutlinedIcon from '@mui/icons-material/RouterOutlined';
import AccountTreeOutlinedIcon from '@mui/icons-material/AccountTreeOutlined';
import AdminPanelSettingsOutlinedIcon from '@mui/icons-material/AdminPanelSettingsOutlined';
import VerifiedUserOutlinedIcon from '@mui/icons-material/VerifiedUserOutlined';
import ScienceOutlinedIcon from '@mui/icons-material/ScienceOutlined';
import { Box, useTheme } from '@mui/material';
import { MenuItemLink, MenuProps, useGetIdentity, useTranslate } from 'react-admin';

const menuItems = [
  { to: '/', labelKey: 'menu.dashboard', icon: <DashboardOutlinedIcon /> },
  { to: '/simulator', labelKey: 'menu.simulator', icon: <ScienceOutlinedIcon />, permissions: ['super', 'admin'] },
  { to: '/network/nodes', labelKey: 'menu.network_nodes', icon: <AccountTreeOutlinedIcon /> },
  { to: '/network/nas', labelKey: 'menu.nas_devices', icon: <RouterOutlinedIcon /> },
  { to: '/radius/users', labelKey: 'menu.radius_users', icon: <PeopleAltOutlinedIcon /> },
  { to: '/radius/profiles', labelKey: 'menu.radius_profiles', icon: <SettingsSuggestOutlinedIcon /> },
  { to: '/radius/online', labelKey: 'menu.online_sessions', icon: <SensorsOutlinedIcon /> },
  { to: '/radius/accounting', labelKey: 'menu.accounting', icon: <ReceiptLongOutlinedIcon /> },
  { to: '/system/config', labelKey: 'menu.system_config', icon: <SettingsOutlinedIcon />, permissions: ['super', 'admin'] },
  { to: '/system/operators', labelKey: 'menu.operators', icon: <AdminPanelSettingsOutlinedIcon />, permissions: ['super', 'admin'] },
  { to: '/system/certificate', labelKey: 'menu.certificates', icon: <VerifiedUserOutlinedIcon />, permissions: ['super', 'admin'] },
];

export const CustomMenu = ({ dense, onMenuClick, logout }: MenuProps) => {
  const currentYear = new Date().getFullYear();
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  const { data: identity } = useGetIdentity();
  const translate = useTranslate();

  // Filter menu items by user permissions
  const filteredMenuItems = menuItems.filter(item => {
    if (!item.permissions) return true; // Menu items without permission limits are visible to everyone
    if (!identity?.level) return false; // Hide permission-gated menus for logged-out users
    return item.permissions.includes(identity.level); // Check whether the user's permission is in the allowed list
  });

  return (
    <Box
      sx={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        // Sidebar background depends on theme
        backgroundColor: isDark ? '#1e293b' : '#115e59',
        color: '#ffffff',
        pt: 0,
        transition: 'background-color 0.3s ease',
      }}
    >
      <Box sx={{ flexGrow: 1, overflowY: 'auto', pt: 1, marginTop: 2 }}>
        {filteredMenuItems.map((item) => (
          <MenuItemLink
            key={item.to}
            to={item.to}
            primaryText={translate(item.labelKey)}
            leftIcon={item.icon}
            dense={dense}
            onClick={onMenuClick}
          />
        ))}
      </Box>

      <Box
        sx={{
          borderTop: '1px solid rgba(255, 255, 255, 0.1)',
          textAlign: 'center',
          px: 2,
          py: 3,
          fontSize: 12,
          whiteSpace: 'normal',
          overflowWrap: 'anywhere',
          color: 'rgba(255, 255, 255, 0.6)',
          transition: 'all 0.3s ease',
        }}
      >
        <div style={{ fontWeight: 600, marginBottom: 4 }}>RADIUS Auth Simulator</div>
        <div>Developed by</div>
        <div style={{ fontWeight: 600 }}>Kushagra Sachdeva</div>
        <div>{currentYear}</div>
        {logout && <Box sx={{ mt: 2 }}>{logout}</Box>}
      </Box>
    </Box>
  );
};
