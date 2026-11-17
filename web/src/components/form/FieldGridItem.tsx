import { ReactNode } from 'react';
import { Box } from '@mui/material';
import { ColumnConfig } from './FieldGrid';

export interface FieldGridItemProps {
  children: ReactNode;
  span?: ColumnConfig;
}

/**
 * Field grid item component
 * Supports column spanning to control field width in the grid
 */
export const FieldGridItem = ({
  children,
  span = {}
}: FieldGridItemProps) => {
  const resolved = {
    xs: span.xs ?? 1,
    sm: span.sm ?? span.xs ?? 1,
    md: span.md ?? span.sm ?? span.xs ?? 1,
    lg: span.lg ?? span.md ?? span.sm ?? span.xs ?? 1
  };

  return (
    <Box
      sx={{
        width: '100%',
        gridColumn: {
          xs: `span ${resolved.xs}`,
          sm: `span ${resolved.sm}`,
          md: `span ${resolved.md}`,
          lg: `span ${resolved.lg}`
        }
      }}
    >
      {children}
    </Box>
  );
};

export default FieldGridItem;
