import { RouterProvider, createRouter } from "@tanstack/react-router";
import ReactDOM from "react-dom/client";

import Loader from "./components/loader";
import Document from "./components/document";
import { routeTree } from "./routeTree.gen";

const router = createRouter({
  routeTree,
  defaultPreload: "intent",
  scrollRestoration: true,
  defaultPendingComponent: () => <Loader />,
  context: {},
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}

const rootElement = document.getElementById("app");

if (!rootElement) {
  throw new Error("Root element not found");
}

await router.load();
if (rootElement.innerHTML) {
  ReactDOM.hydrateRoot(
    document,
    <Document>
      <RouterProvider router={router} />
    </Document>,
  );
} else {
  ReactDOM.createRoot(rootElement).render(<RouterProvider router={router} />);
}
