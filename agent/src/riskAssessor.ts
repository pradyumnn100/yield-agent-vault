import { GoogleGenAI } from "@google/genai";

const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  throw new Error("GEMINI_API_KEY is not set in .env");
}
const ai = new GoogleGenAI({ apiKey });

export interface RiskAssessment {
  trust: boolean;
  confidence: number;
  reasoning: string;
}

interface APYSnapshot {
  timestamp: string;
  aaveAPY: string;
  compoundAPY: string;
}

export async function assessRebalanceRisk(
  candidateName: string,
  candidateAPY: string,
  currentName: string,
  currentAPY: string,
  history: APYSnapshot[]
): Promise<RiskAssessment> {
  const historyText = history
    .map((h) => `${h.timestamp}: Aave=${h.aaveAPY}, Compound=${h.compoundAPY}`)
    .join("\n");

  const prompt = `You are a risk-assessment layer for a DeFi yield-rebalancing agent. Your ONLY job is to judge whether a proposed move looks trustworthy — you do not decide whether to move, only whether the yield signal looks credible. A separate system has already determined the candidate beats the current position by a meaningful margin; your job is purely to catch red flags.

Current position: ${currentName} at ${currentAPY} bps
Candidate: ${candidateName} at ${candidateAPY} bps

Recent APY history (most recent last):
${historyText || "No history yet (first cycle)"}

Consider: a sudden large jump with no gradual prior trend often signals a temporary incentive program about to end, or a data anomaly, rather than durable yield. A gradual, sustained increase is more trustworthy than an isolated spike.

Respond with ONLY valid JSON, no other text, in exactly this shape:
{"trust": boolean, "confidence": number between 0 and 1, "reasoning": "one to two sentences"}`;

  const interaction = await ai.interactions.create({
    model: "gemini-3.6-flash",
    input: prompt,
  });

  const raw = interaction.output_text ?? "";

  try {
    const cleaned = raw.replace(/```json|```/g, "").trim();
    const parsed = JSON.parse(cleaned);
    return {
      trust: Boolean(parsed.trust),
      confidence: Number(parsed.confidence),
      reasoning: String(parsed.reasoning),
    };
  } catch {
    // Fail safe: an unparseable response defaults to NOT trusting the move
    return { trust: false, confidence: 0, reasoning: `Could not parse Gemini response: ${raw.slice(0, 200)}` };
  }
}