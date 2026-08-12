import { ChakraProvider, defaultSystem } from "@chakra-ui/react";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { I18nextProvider } from "react-i18next";

import { App } from "./app";
import { i18n } from "./lib/i18n";
import "./styles.css";

const root = document.getElementById("root");
if (root === null) {
  throw new Error("MediaForge root element is missing");
}

createRoot(root).render(
  <StrictMode>
    <I18nextProvider i18n={i18n}>
      <ChakraProvider value={defaultSystem}>
        <App />
      </ChakraProvider>
    </I18nextProvider>
  </StrictMode>,
);
