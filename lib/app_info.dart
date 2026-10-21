const appName = 'OrientMark QR';
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
const appDeveloper = String.fromEnvironment('APP_DEVELOPER');
const appOrganization = String.fromEnvironment('APP_ORGANIZATION');
final repositoryUri = Uri.parse('https://github.com/orient-mark/qr-generator');
final releasesUri = Uri.parse(
  'https://github.com/orient-mark/qr-generator/releases/latest',
);
