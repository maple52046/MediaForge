import { describe, expect, it } from "vitest";

import { isActiveJob, outputPathForMode } from "./media";

describe("media presentation policy", () => {
  it.each([
    ["videoWithAudio", "/media/clip.mp4"],
    ["videoOnly", "/media/clip.mp4"],
    ["audioOnly", "/media/clip.mp3"],
  ] as const)("derives the %s destination", (mode, expected) => {
    expect(outputPathForMode("/media/clip.mov", mode)).toBe(expected);
  });

  it("handles dotted directories and Windows-style paths", () => {
    expect(outputPathForMode("/media.archive/clip", "videoOnly")).toBe("/media.archive/clip.mp4");
    expect(outputPathForMode("C:\\media.archive\\clip.wav", "audioOnly")).toBe(
      "C:\\media.archive\\clip.mp3",
    );
  });

  it("only locks controls for active lifecycle states", () => {
    expect(isActiveJob("preparing")).toBe(true);
    expect(isActiveJob("running")).toBe(true);
    expect(isActiveJob("completed")).toBe(false);
    expect(isActiveJob("cancelled")).toBe(false);
    expect(isActiveJob("failed")).toBe(false);
  });
});
