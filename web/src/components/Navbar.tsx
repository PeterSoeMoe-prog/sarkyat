"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

type NavItem = {
  href: string;
  label: string;
  icon: string;
};

const items: NavItem[] = [
  { href: "/", label: "Home", icon: "⌂" },
  { href: "/calendar", label: "Calendar", icon: "📅" },
  { href: "/category", label: "Category", icon: "▦" },
  { href: "/settings", label: "Settings", icon: "⚙︎" },
];

export function Navbar() {
  const pathname = usePathname();

  const isActive = (href: string) => {
    if (href === "/") return pathname === "/";
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  return (
    <div className="fixed inset-x-0 bottom-0 z-50 pb-[env(safe-area-inset-bottom)]">
      <div className="mx-auto w-full max-w-md px-4">
        <nav className="mb-3 rounded-2xl bg-[var(--surface)] backdrop-blur-2xl border border-[color:var(--border)] shadow-[0_8px_32px_rgba(0,0,0,0.15)] dark:shadow-[0_8px_32px_rgba(0,0,0,0.4)]">
          <div className="grid grid-cols-4 px-1">
            {items.map((it) => {
              const active = isActive(it.href);
              return (
                <Link
                  key={it.href}
                  href={it.href}
                  className={
                    "flex flex-col items-center justify-center gap-1 py-3 text-[11px] font-bold transition-all " +
                    (active
                      ? "text-[color:var(--foreground)] scale-110"
                      : "text-[color:var(--muted-strong)] opacity-70 hover:opacity-100")
                  }
                  aria-current={active ? "page" : undefined}
                >
                  <span className={"text-[16px] leading-none " + (active ? "opacity-100" : "opacity-80")}>
                    {it.icon}
                  </span>
                  <span className="leading-none">{it.label}</span>
                </Link>
              );
            })}
          </div>
        </nav>
      </div>
    </div>
  );
}
