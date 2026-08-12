import { describe, expect, it, vi } from "vitest";

vi.mock("@tauri-apps/api/core", () => ({
  convertFileSrc: (path: string) => `asset://localhost/${path}`,
  invoke: vi.fn(),
}));
vi.mock("@tauri-apps/api/event", () => ({ listen: vi.fn() }));

import { previewUrl, toApiError } from "./ipc";

describe("desktop contract helpers", () => {
  it("preserves structured backend errors for localized mapping", () => {
    expect(toApiError({ code: "outputExists", message: "already exists" })).toEqual({
      code: "outputExists",
      message: "already exists",
    });
  });

  it("normalizes unknown failures", () => {
    expect(toApiError(new Error("boom"))).toEqual({ code: "unexpected", message: "boom" });
  });

  it("delegates preview paths to the Tauri asset protocol", () => {
    expect(previewUrl("/tmp/movie.mov")).toBe("asset://localhost//tmp/movie.mov");
  });
});
