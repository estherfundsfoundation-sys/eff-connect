export type StudentProfile = { major?: string | null; year?: string | null; state?: string | null; first_gen?: boolean | null; gpa_band?: string | null; barriers?: string[] | null; identity_tags?: string[] | null };
export type Scholarship = { eligibility_tags?: string[] | null; deadline?: string | null };

const normal = (value: string) => value.trim().toLowerCase();
export function scoreScholarship(s: Scholarship, p: StudentProfile) {
  const tags = new Set((s.eligibility_tags ?? []).map(normal));
  let score = 0; const matches: string[] = [];
  const test = (value: string | null | undefined, label: string, points: number) => {
    if (value && tags.has(normal(value))) { score += points; matches.push(label); }
  };
  test(p.major, "Your major", 4); test(p.year, "Your year", 3); test(p.state, "Your state", 3); test(p.gpa_band, "Your GPA range", 2);
  if (p.first_gen && (tags.has("first-gen") || tags.has("first generation"))) { score += 3; matches.push("First-generation"); }
  for (const tag of [...(p.barriers ?? []), ...(p.identity_tags ?? [])]) test(tag, tag, 2);
  return { score, matches };
}
