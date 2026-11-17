/**
 * Storage utilities
 * Manages localStorage data, separating what to keep from what to clear
 */

// localStorage keys kept on logout
const PERSISTENT_KEYS = ['locale', 'theme'];

/**
 * Clear auth-related localStorage data
 * Keep user preferences (language, theme, etc.)
 */
export const clearAuthStorage = () => {
  const keysToRemove = ['token', 'username', 'permissions', 'user'];
  keysToRemove.forEach(key => localStorage.removeItem(key));
};

/**
 * Clear all localStorage data except user preferences
 */
export const clearAllStorageExceptPreferences = () => {
  // Save data to keep
  const persistentData: Record<string, string | null> = {};
  PERSISTENT_KEYS.forEach(key => {
    persistentData[key] = localStorage.getItem(key);
  });
  
  // Clear all data
  localStorage.clear();
  
  // Restore kept data
  PERSISTENT_KEYS.forEach(key => {
    if (persistentData[key] !== null) {
      localStorage.setItem(key, persistentData[key]!);
    }
  });
};
