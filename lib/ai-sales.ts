import { db } from '@/lib/db';

function clean(value: unknown) {
  return String(value ?? '').replace(/\s+/g, ' ').trim();
}

export async function buildCatalogReply(shopId: string, customerMessage: string) {
  const shop = await db.shop.findUnique({ where: { id: shopId } });
  if (!shop) return null;

  const products = await db.product.findMany({
    where: { shopId, stock: { gt: 0 } },
    orderBy: [{ isFeatured: 'desc' }, { createdAt: 'desc' }],
    take: 40,
    select: { id: true, title: true, description: true, price: true, compareAtPrice: true, stock: true, category: true, brand: true, images: true, affiliateLink: true },
  });

  const catalog = products.map((p) => ({
    id: p.id,
    title: p.title,
    description: clean(p.description).slice(0, 500),
    priceGHS: Number(p.price),
    compareAtPriceGHS: p.compareAtPrice ? Number(p.compareAtPrice) : undefined,
    stock: p.stock,
    category: p.category,
    brand: p.brand || undefined,
    link: p.affiliateLink || `/product/${p.id}`,
  }));

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    const q = customerMessage.toLowerCase();
    const matches = catalog.filter((p) => `${p.title} ${p.category} ${p.brand || ''}`.toLowerCase().includes(q));
    if (!matches.length) return `Thanks for contacting ${shop.name}. Tell me what product or category you are looking for and I’ll check the catalog.`;
    return matches.slice(0, 3).map((p) => `${p.title} — GHS ${p.priceGHS.toFixed(2)} (${p.stock} in stock)\n${p.link}`).join('\n\n');
  }

  const baseUrl = process.env.AI_BASE_URL || 'https://api.openai.com/v1';
  const model = process.env.AI_MODEL || 'gpt-4o-mini';
  const system = [
    `You are the sales assistant for ${shop.name}.`,
    shop.description ? `Shop description: ${shop.description}` : '',
    'Only use facts present in the catalog below. Never invent a product, price, discount, stock level, delivery promise, or policy.',
    'Be concise and helpful. Recommend up to three matching products when appropriate.',
    'Prices are in GHS. Include the product link when recommending a product.',
    'If the customer wants a human, is upset, asks for something outside the catalog, or needs an exception, reply with exactly: HANDOFF_REQUIRED',
    shop.botSystemPrompt || '',
    `CATALOG:\n${JSON.stringify(catalog)}`,
  ].filter(Boolean).join('\n\n');

  const response = await fetch(`${baseUrl.replace(/\/$/, '')}/chat/completions`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model, temperature: 0.2, messages: [{ role: 'system', content: system }, { role: 'user', content: customerMessage }], max_tokens: 500 }),
  });
  if (!response.ok) throw new Error('AI provider request failed');
  const data = await response.json();
  return clean(data?.choices?.[0]?.message?.content) || null;
}
