import { Clerk } from '@clerk/clerk-js';

const publishableKey = import.meta.env.VITE_CLERK_PUBLISHABLE_KEY as string;

if (!publishableKey) {
  throw new Error('VITE_CLERK_PUBLISHABLE_KEY is not set');
}

export const clerk = new Clerk(publishableKey);

let loaded = false;

export async function initClerk(): Promise<void> {
  if (loaded) return;
  await clerk.load();
  loaded = true;
}

export function isSignedIn(): boolean {
  return !!clerk.user;
}

export async function getToken(): Promise<string | null> {
  if (!clerk.session) return null;
  return clerk.session.getToken();
}

export function openSignIn(): void {
  clerk.openSignIn();
}

export async function signOut(): Promise<void> {
  await clerk.signOut();
}
