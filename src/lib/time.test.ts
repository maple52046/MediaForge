import { describe, expect, it } from "vitest";

import { formatTime, parseTime } from "./time";

describe("media time", () => {
  it("formats stable display and editing values", () => {
    expect(formatTime(3_723_456)).toBe("01:02:03");
    expect(formatTime(3_723_456, true)).toBe("01:02:03.456");
  });

  it("parses valid values and rejects invalid fields", () => {
    expect(parseTime("01:02:03.4")).toBe(3_723_400);
    expect(parseTime("00:60:00")).toBeUndefined();
    expect(parseTime("2:03")).toBeUndefined();
  });
});
