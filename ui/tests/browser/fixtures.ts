import { randomUUID } from 'node:crypto';
import type { Page } from '@playwright/test';
import type { components } from '../../src/api-types';
import type {
  ListTokensResponse,
  CreateTokenResponse,
} from '../../src/token-api-types';

export type MockToken = components['schemas']['Token'];

export const makeToken = (overrides: Partial<MockToken> = {}): MockToken => {
  const nowSeconds = Math.floor(Date.now() / 1000);
  return {
    name: randomUUID(),
    id: randomUUID(),
    iat: nowSeconds,
    nbf: nowSeconds,
    exp: nowSeconds + 60 * 60 * 24 * 30,
    paths: [],
    scopes: [],
    rotatable: false,
    ...overrides,
  };
};

/**
 * Intercepts token-service API calls with an in-memory fake so tests don't
 * need a real backend. Returns the backing array for assertions.
 */
export const mockTokenApi = async (
  page: Page,
  initialTokens: MockToken[] = []
): Promise<MockToken[]> => {
  const tokens: ListTokensResponse = [...initialTokens];

  await page.route('**/token-service/api/v1/token*', async (route) => {
    const request = route.request();
    const url = new URL(request.url());

    switch (request.method()) {
      case 'GET': {
        await route.fulfill({ json: tokens });
        return;
      }
      case 'POST': {
        const body = new URLSearchParams(request.postData() ?? '');
        const nowSeconds = Math.floor(Date.now() / 1000);
        const generatedId = randomUUID();
        const created = makeToken({
          name: body.get('name') ?? randomUUID(),
          id: generatedId,
          nbf: body.has('nbf') ? Number(body.get('nbf')) : nowSeconds,
          exp: body.has('exp')
            ? Number(body.get('exp'))
            : nowSeconds + 60 * 60 * 24 * 30,
        });
        tokens.push(created);
        const response: CreateTokenResponse = `${generatedId}.${randomUUID()}`;
        await route.fulfill({ json: response });
        return;
      }
      case 'DELETE': {
        const name = url.searchParams.get('name');
        const index = tokens.findIndex((token) => token.name === name);
        if (index !== -1) {
          tokens.splice(index, 1);
        }
        await route.fulfill({ status: 204, body: '' });
        return;
      }
      default: {
        await route.continue();
      }
    }
  });

  return tokens;
};
