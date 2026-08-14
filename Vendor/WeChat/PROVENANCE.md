# Tencent WeChat OpenSDK provenance

- Product: WeChat OpenSDK for iOS, official XCFramework artifact labelled `NoPay`
- Version: `2.0.7`
- Developer: Shenzhen Tencent Computer Systems Company Limited
- Official documentation: <https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Downloads/iOS_Resource.html>
- Official artifact: <https://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.7_NoPay.zip>
- Download SHA-256: `882d99dabd26aceb6ad3e7a12c4b7da8a37626e68a04c8b89740c2275db24258`
- Device binary SHA-256: `d762a75ab8129fe5331de39c3a01370dc3f0284897baefb6339422c56c668e45`
- Simulator binary SHA-256: `8bc77e5a56f9bdbaab69c51fae7b003f28ce64e21befcf0255fc8fde8a2b4b07`

Tencent's `NoPay` archive is intentionally used because WECHAT-006 does not
authorize payment functionality. The distributed framework retains shared payment
declarations and binary symbols behind the `BUILD_WITHOUT_PAY` preprocessor guard;
the application target defines `BUILD_WITHOUT_PAY=1` and integrates only `WXApi`,
`SendAuthReq`, and `SendAuthResp` for personal-account login. No payment request,
configuration, entitlement, UI, or application code is included.

The XCFramework is checked in without repackaging so CI and reviewed builds use the
exact hashed Tencent artifact rather than a mutable mirror.
