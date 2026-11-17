import polyglotI18nProvider from 'ra-i18n-polyglot';
import enUS from './en-US';

export const i18nProvider = polyglotI18nProvider(() => enUS, 'en-US', [{ locale: 'en-US', name: 'English' }], {
  allowMissing: true,
});
