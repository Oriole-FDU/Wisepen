import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import { SetupProvider } from "./state/SetupContext";
import "./styles.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <SetupProvider>
      <App />
    </SetupProvider>
  </StrictMode>,
);
