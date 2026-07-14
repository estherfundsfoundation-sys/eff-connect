type Json = Record<string, unknown> | Record<string, unknown>[];

function config() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase server configuration is incomplete.");
  return { url, key };
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const { url, key } = config();
  const response = await fetch(`${url}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
      ...(init.headers || {}),
    },
    cache: "no-store",
  });
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Supabase request failed (${response.status}): ${detail}`);
  }
  const text = await response.text();
  return (text ? JSON.parse(text) : null) as T;
}

export const db = {
  one: async <T>(table: string, query: string) => {
    const rows = await request<T[]>(`${table}?${query}&limit=1`, { headers: { Accept: "application/vnd.pgrst.object+json" } });
    return rows as unknown as T;
  },
  list: <T>(table: string, query: string) => request<T[]>(`${table}?${query}`),
  insert: <T extends Json>(table: string, values: T) => request(`${table}`, { method: "POST", body: JSON.stringify(values) }),
  update: <T extends Json>(table: string, query: string, values: T) => request(`${table}?${query}`, { method: "PATCH", body: JSON.stringify(values) }),
};
