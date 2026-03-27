import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['node_modules/', 'out/', 'cdk.out/'] },
  ...tseslint.configs.recommended,
);
