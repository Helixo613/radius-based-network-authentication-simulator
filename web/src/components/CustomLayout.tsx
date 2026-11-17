import type { SxProps, Theme } from '@mui/material';
import { Layout, LayoutProps } from 'react-admin';

import { CustomAppBar } from './CustomAppBar';
import { CustomMenu } from './CustomMenu';

type CustomLayoutProps = LayoutProps & { sx?: SxProps<Theme> };

export const CustomLayout = ({ sx, ...rest }: CustomLayoutProps) => (
  <Layout
    {...rest}
    appBar={CustomAppBar}
    menu={CustomMenu}
    sx={[
      {
        // Fixed top AppBar (stays visible on scroll)
        '& .MuiAppBar-root': {
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          zIndex: 1200,
        },
        // Leave room for the fixed AppBar
        '& .RaLayout-appFrame': {
          marginTop: '48px',
        },
        // Fixed left menu (does not scroll)
        '& .RaSidebar-fixed': {
          position: 'fixed',
          top: '48px',
          height: 'calc(100vh - 48px)',
          overflowY: 'auto',
        },
        // Content area styles
        '& .RaLayout-content': {
          padding: { xs: 2, md: 3, lg: 4 },
          minHeight: 'calc(100vh - 48px)',
          transition: 'background-color 0.3s ease',
        },
      },
      ...(Array.isArray(sx) ? sx : sx ? [sx] : []),
    ]}
  />
);
