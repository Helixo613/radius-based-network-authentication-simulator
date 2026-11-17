import { Box, Typography } from '@mui/material';

export interface EmptyValueProps {
  message?: string;
}

/**
 * Empty state component
 * Shows an empty-value placeholder on detail pages
 */
export const EmptyValue = ({ message = 'No data' }: EmptyValueProps) => (
  <Box
    sx={{
      display: 'flex',
      alignItems: 'center',
      gap: 0.5,
      color: 'text.disabled',
      fontStyle: 'italic',
      fontSize: '0.85rem',
    }}
  >
    <Typography variant="body2" sx={{ opacity: 0.6 }}>
      {message}
    </Typography>
  </Box>
);

export default EmptyValue;
