import { MedicationRiskAnalysis, MedicationRiskPair,
  PolypharmacySideEffectRisk } from './ApiService';
import { AnalysisResult, OrganRisk } from '../components/SafetyAnalysisCard';

/**
 * Maps the backend's polypharmacy analysis onto the Safety Analysis Card.
 *
 * The two models do not line up on their own:
 *   - the backend answers PER INGREDIENT PAIR, each pair carrying its own organ
 *     probabilities; the card shows ONE row per organ.
 *   - the model names organ SYSTEMS ("Hepatobiliary (Liver)"); the card draws
 *     markers on a body image keyed by short ids ("liver").
 *   - the model gives probabilities; the card colours by low/medium/high.
 *
 * So this file folds pairs into organs (worst pair wins), translates the
 * system labels, and buckets the probabilities. The probability itself is kept
 * and shown, because a bucket alone would hide how the colour was chosen.
 */

/**
 * Display buckets. These are NOT clinical thresholds - the model emits a
 * probability, and there is no cut-off in the release that says where "high"
 * begins. They exist to colour the card, and every row still shows the raw
 * percentage next to them so the number is never hidden behind the colour.
 */
const HIGH_RISK_THRESHOLD: number = 0.5;
const MEDIUM_RISK_THRESHOLD: number = 0.2;

/** How many side effects to name in an organ's detail text. */
const MAX_SIDE_EFFECTS_SHOWN: number = 3;

class OrganMapping {
  organId: string = '';
  keyword: string = '';
  constructor(organId: string, keyword: string) {
    this.organId = organId;
    this.keyword = keyword;
  }
}

/**
 * The model's 15 organ systems (`organ_order` in the release's
 * meddra_hierarchy.json) mapped onto the card's ids. Matching is by keyword so
 * a reworded label ("Hepatobiliary" -> "Hepatobiliary (Liver)") still lands.
 *
 * Only the first nine have a spot on the body image; the rest are body-wide and
 * appear in the list below the figure - see `hasBodyPosition` in
 * SafetyAnalysisCard.
 */
const ORGAN_MAPPINGS: OrganMapping[] = [
  new OrganMapping('vascular', 'cardiovascular'),
  new OrganMapping('stomach', 'gastrointestinal'),
  new OrganMapping('brain', 'nervous'),
  new OrganMapping('liver', 'hepatobiliary'),
  new OrganMapping('kidney', 'renal'),
  new OrganMapping('lungs', 'respiratory'),
  new OrganMapping('blood', 'hematologic'),
  new OrganMapping('skin', 'dermatologic'),
  new OrganMapping('psychiatric', 'psychiatric'),
  new OrganMapping('endocrine', 'metabolism'),
  new OrganMapping('joints', 'musculoskeletal'),
  new OrganMapping('immune', 'immune'),
  new OrganMapping('eyeEar', 'ophthalmic'),
  new OrganMapping('infection', 'infections'),
  new OrganMapping('systemic', 'general disorders')
];

/** Working accumulator while folding pairs together. */
class OrganAccumulator {
  organId: string = '';
  label: string = '';
  probability: number = 0;
  culprits: string[] = [];
  sideEffects: string[] = [];
}

export class RiskAnalysis {
  /** Model organ-system label -> body-map id. Unknown labels keep a slug. */
  static organIdFor(organLabel: string): string {
    const lower: string = organLabel.toLowerCase();
    for (const mapping of ORGAN_MAPPINGS) {
      if (lower.includes(mapping.keyword)) {
        return mapping.organId;
      }
    }
    // Unknown system: keep something stable and let the card fall back to its
    // default icon. Better than dropping a risk the model did report.
    return lower.replace(/[^a-z0-9]+/g, '-');
  }

  static levelFor(probability: number): 'low' | 'medium' | 'high' {
    if (probability >= HIGH_RISK_THRESHOLD) {
      return 'high';
    }
    if (probability >= MEDIUM_RISK_THRESHOLD) {
      return 'medium';
    }
    return 'low';
  }

  static percent(probability: number): string {
    return `${Math.round(probability * 100)}%`;
  }

  private static pairLabel(pair: MedicationRiskPair): string {
    return `${pair.medicationA.name} + ${pair.medicationB.name}`;
  }

  /**
   * Folds every pair's organ risks into one row per organ, keeping the WORST
   * probability seen for that organ. Taking the worst (rather than an average)
   * is deliberate: a dangerous interaction between two of five medications must
   * not be diluted by the harmless pairs around it.
   */
  static toAnalysisResult(analysis: MedicationRiskAnalysis): AnalysisResult {
    const byOrgan: Map<string, OrganAccumulator> = new Map<string, OrganAccumulator>();

    for (const pair of analysis.pairs) {
      const pairName: string = RiskAnalysis.pairLabel(pair);
      const topSideEffects: string[] = pair.sideEffectRisks
        .slice(0, MAX_SIDE_EFFECTS_SHOWN)
        .map((s: PolypharmacySideEffectRisk) => `${s.label} (${RiskAnalysis.percent(s.probability)})`);

      for (const organ of pair.organRisks) {
        const organId: string = RiskAnalysis.organIdFor(organ.organ);
        let entry: OrganAccumulator | undefined = byOrgan.get(organId);
        if (entry === undefined) {
          entry = new OrganAccumulator();
          entry.organId = organId;
          entry.label = organ.organ;
          entry.probability = organ.probability;
          entry.culprits = [pairName];
          entry.sideEffects = topSideEffects;
          byOrgan.set(organId, entry);
          continue;
        }
        if (organ.probability > entry.probability) {
          entry.probability = organ.probability;
          // The side effects shown belong to the pair that set the peak, so
          // the detail text and the number always describe the same pair.
          entry.sideEffects = topSideEffects;
        }
        if (!entry.culprits.includes(pairName)) {
          entry.culprits.push(pairName);
        }
      }
    }

    const organs: OrganRisk[] = [];
    byOrgan.forEach((entry: OrganAccumulator) => {
      organs.push({
        organId: entry.organId,
        label: entry.label,
        riskLevel: RiskAnalysis.levelFor(entry.probability),
        probability: entry.probability,
        culpritMeds: entry.culprits,
        detailMessage: RiskAnalysis.detailFor(entry)
      });
    });
    // Worst first, so the rows the patient should read are at the top.
    organs.sort((a: OrganRisk, b: OrganRisk) =>
      (b.probability !== undefined ? b.probability : 0) - (a.probability !== undefined ? a.probability : 0));

    return {
      overallStatus: RiskAnalysis.overallStatus(organs),
      message: RiskAnalysis.overallMessage(organs, analysis),
      organs: organs
    };
  }

  private static detailFor(entry: OrganAccumulator): string {
    let text: string = `Predicted risk for ${entry.label}: ${RiskAnalysis.percent(entry.probability)}.`;
    if (entry.sideEffects.length > 0) {
      text += ` Most likely effects: ${entry.sideEffects.join(', ')}.`;
    }
    return text;
  }

  private static overallStatus(organs: OrganRisk[]): 'safe' | 'medium' | 'high' {
    for (const organ of organs) {
      if (organ.riskLevel === 'high') {
        return 'high';
      }
    }
    for (const organ of organs) {
      if (organ.riskLevel === 'medium') {
        return 'medium';
      }
    }
    return 'safe';
  }

  private static overallMessage(organs: OrganRisk[], analysis: MedicationRiskAnalysis): string {
    const pairCount: number = analysis.pairs.length;
    const scope: string = pairCount === 1 ? '1 medication pair' : `${pairCount} medication pairs`;

    if (organs.length === 0) {
      return `No organ risk was predicted across ${scope}. ${analysis.disclaimer}`;
    }
    const worst: OrganRisk = organs[0];
    const worstPercent: string = RiskAnalysis.percent(
      worst.probability !== undefined ? worst.probability : 0);

    if (worst.riskLevel === 'high') {
      return `Elevated risk for ${worst.label} (${worstPercent}) across ${scope}. Talk to your doctor before changing anything. ${analysis.disclaimer}`;
    }
    if (worst.riskLevel === 'medium') {
      return `Moderate risk for ${worst.label} (${worstPercent}) across ${scope}. ${analysis.disclaimer}`;
    }
    return `Only low risks were predicted across ${scope}. ${analysis.disclaimer}`;
  }

  /**
   * Whether the model saw reduced-confidence input for any pair, so the screen
   * can say so instead of presenting a shaky number as a firm one.
   */
  static hasReducedConfidence(analysis: MedicationRiskAnalysis): boolean {
    for (const pair of analysis.pairs) {
      if (pair.confidence === 'reduced') {
        return true;
      }
    }
    return false;
  }

  /** Every distinct warning the model attached to any pair. */
  static warnings(analysis: MedicationRiskAnalysis): string[] {
    const seen: string[] = [];
    for (const pair of analysis.pairs) {
      for (const warning of pair.warnings) {
        if (!seen.includes(warning)) {
          seen.push(warning);
        }
      }
    }
    return seen;
  }
}
