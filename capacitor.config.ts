import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.sanju.app",
  appName: "三句",
  webDir: "mobile/out",
  backgroundColor: "#ffffff",
  ios: {
    contentInset: "never",
    preferredContentMode: "mobile",
    backgroundColor: "#ffffff",
  },
};

export default config;
