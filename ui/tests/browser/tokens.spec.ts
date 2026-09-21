import { randomUUID } from 'node:crypto';
import { test, expect } from '@playwright/test';
import { makeToken, mockTokenApi } from './fixtures';

test.describe('Tokens page', () => {
  test('shows an empty state when there are no tokens', async ({ page }) => {
    await mockTokenApi(page, []);
    await page.goto('/');

    await expect(page.getByTestId('empty-tokens-message')).toBeVisible();
  });

  test('lists existing tokens', async ({ page }) => {
    const token = makeToken();
    await mockTokenApi(page, [token]);
    await page.goto('/');

    await expect(page.getByTestId(`token-row-${token.name}`)).toBeVisible();
  });

  test('creates a new token and shows the one-time secret', async ({
    page,
  }) => {
    const name = randomUUID();
    await mockTokenApi(page, []);
    await page.goto('/');

    await page.getByTestId('create-token-button').click();
    await page.getByTestId('token-name-input').fill(name);
    await page.getByTestId('submit-create-token-button').click();

    await expect(page.getByTestId('created-token-alert')).toBeVisible();
    await expect(page.getByTestId(`token-row-${name}`)).toBeVisible();
  });

  test('deletes a token', async ({ page }) => {
    const token = makeToken();
    await mockTokenApi(page, [token]);
    await page.goto('/');

    const row = page.getByTestId(`token-row-${token.name}`);
    await expect(row).toBeVisible();
    await row.getByTestId('delete-token-button').click();

    await expect(page.getByTestId('empty-tokens-message')).toBeVisible();
  });
});
