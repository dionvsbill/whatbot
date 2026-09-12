import { Search, ShoppingCart, Heart, User, MapPin, Menu } from 'lucide-react';

const categories = ['All Categories', 'Phones', 'Fashion', 'Electronics', 'Home', 'Beauty', 'Jumia Imported', 'Amazon Deals'];

export default function HomePage() {
  return (
    <main className="min-h-screen bg-slate-50">
      <header className="sticky top-0 z-50 border-b bg-white shadow-sm">
        <div className="mx-auto flex h-[72px] max-w-7xl items-center gap-5 px-4">
          <div className="flex items-center gap-3 font-bold text-xl"><div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-900 text-white">W</div><span>WhatBot</span></div>
          <button className="hidden items-center gap-2 rounded-lg border px-3 py-2 md:flex"><Menu className="h-5 w-5" /> Categories</button>
          <div className="relative flex-1"><Search className="absolute left-3 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-400" /><input className="w-full rounded-lg border bg-slate-50 py-3 pl-10 pr-4 outline-none focus:border-slate-900" placeholder="Search products and shops" /></div>
          <button className="hidden items-center gap-1 text-sm lg:flex"><MapPin className="h-5 w-5" /> Accra, Ghana</button>
          <button aria-label="Wishlist"><Heart className="h-5 w-5" /></button>
          <button aria-label="Cart" className="relative"><ShoppingCart className="h-5 w-5" /><span className="absolute -right-2 -top-2 rounded-full bg-slate-900 px-1.5 text-[10px] text-white">0</span></button>
          <button aria-label="Account"><User className="h-5 w-5" /></button>
        </div>
        <nav className="hidden h-12 items-center gap-7 overflow-x-auto border-t bg-slate-50 px-4 text-sm md:flex md:justify-center">{categories.map((category) => <span key={category} className="whitespace-nowrap">{category}</span>)}</nav>
      </header>
      <section className="mx-auto max-w-7xl px-4 py-14">
        <div className="rounded-2xl bg-slate-900 px-6 py-16 text-white md:px-12"><p className="mb-3 text-sm uppercase tracking-[0.2em] text-slate-300">Ghana marketplace</p><h1 className="max-w-3xl text-4xl font-bold tracking-tight md:text-6xl">Discover products from trusted Ghanaian shops.</h1><p className="mt-5 max-w-2xl text-slate-300">Shop native products and verified imported deals in one place, with secure Paystack checkout and seller support.</p><div className="mt-8 flex gap-3"><button className="rounded-lg bg-white px-5 py-3 font-semibold text-slate-900">Start shopping</button><button className="rounded-lg border border-slate-600 px-5 py-3 font-semibold">Become a seller</button></div></div>
      </section>
    </main>
  );
}
