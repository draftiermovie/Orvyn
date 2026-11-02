// Editorial estimates within each task category, not measured benchmark scores.
// Unknown/custom models deliberately have no inferred score.
export const modelQuality: Record<string, number> = {
  "qwen3-4b":4, "gemma3-4b-vision":4, "mimo-vl-7b":4,
  "qwen25-05b": 1, "qwen25-15b": 2, "qwen25-3b": 3, "qwen25-7b": 4,
  "coder-05b": 1, "coder-15b": 2, "coder-3b": 3, "coder-7b": 4,
  "llama32-1b": 2, "llama32-3b": 3, "smollm2": 2,
  "deepseek-15b": 2, "deepseek-7b": 4,
  "phi35": 3, "phi4-mini": 4, "gemma3-1b": 2,
  "qwen3-06b": 2, "qwen3-17b": 3, "qwen3": 4, "glm-ocr": 4,
  "mimo-7b": 4, "mimo-7b-q3": 3, "mimo-7b-q5": 4, "mimo-7b-q8": 4,
};
