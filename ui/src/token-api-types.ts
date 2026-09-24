import type { operations } from './api-types';

type JsonResponse<
  Operation extends keyof operations,
  Status extends keyof operations[Operation]['responses'],
> = operations[Operation]['responses'][Status] extends {
  content: { 'application/json': infer Body };
}
  ? Body
  : never;

type JsonRequestBody<Operation extends keyof operations> =
  operations[Operation]['requestBody'] extends {
    content: { 'application/json': infer Body };
  }
    ? Body
    : never;

export type ListTokensResponse = JsonResponse<
  'list_tokens_api_v1_token_get',
  200
>;
export type CreateTokenResponse = JsonResponse<'create_api_v1_token_post', 201>;
export type AttestTokensRequest =
  JsonRequestBody<'attestation_api_v1_token_attestation_patch'>;
