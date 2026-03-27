# Watch Over Pro

家族の位置情報をリアルタイムで共有・見守るiOSアプリ。

## 概要

**見守る側（Watcher）** と **見守られる側（Watched）** の2モードで動作し、家族間でリアルタイムの位置共有を行う。

- リアルタイム位置追跡
- 停止検知（3分以上の滞在を自動記録）
- 24時間のルート履歴
- 招待コードによるファミリーペアリング
- Apple Sign In 認証

## 技術スタック

**iOS**
- SwiftUI / iOS 17+ / Swift 6.0
- `@Observable` + `async/await`
- CoreLocation（バックグラウンド位置取得）
- AWS Amplify Swift 2.0+

**Backend（AWS）**
- Cognito（Apple Sign In + Custom Auth）
- AppSync（GraphQL + リアルタイム Subscriptions）
- DynamoDB
- CDK（TypeScript）

## ディレクトリ

```
Domain/       エンティティ, リポジトリプロトコル, ユースケース
Data/         AppSync/Cognito 実装
Presentation/ Views, Components, ViewModels
Infrastructure/ AWS設定, Location, 通知, バックグラウンドタスク
infra/        CDK (auth / data / api / billing)
```
