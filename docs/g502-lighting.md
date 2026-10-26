# G502 X PLUS 板载灯光

灯光页分别编辑日常和闲置时的机身灯效，支持关闭、常亮、呼吸、色彩循环。选择后先暂存，点击“保存到鼠标”才写入当前板载配置。两组修改合并为一次扇区写入。

保存前备份所有 Flash 扇区，写入后读回当前扇区，并检查其他扇区没有改变。保留按键、DPI、闲置和休眠时间、指示灯设置及其他配置。失败时保留备份并要求重新读取。

G502 X PLUS 的自定义动画选择器可能覆盖基础灯效。保存灯效时会清除此选择器，不删除动画数据。界面会提示这个影响，不会把有自定义动画覆盖的基础“关闭”值直接当成实际灯光状态。若希望始终关闭机身灯，请将日常和闲置两组都设为“关闭”并保存。

## 协议依据与范围

- [libratbag HID++ profile layout and serializer](https://github.com/libratbag/libratbag/blob/master/src/hidpp20.c)：灯效块、自定义动画选择器及 0x8100 读写协议。
- [libratbag G502 X PLUS driver quirk](https://github.com/libratbag/libratbag/blob/master/src/driver-hidpp20.c)：该机型使用第二个 LED 槽位。此实现仅修改日常偏移 219、闲置偏移 241 的两个 11 字节机身灯效块，以及偏移 252 的动画选择器和 CRC；不修改两个指示灯槽位。
- [libratbag LED effect structures](https://github.com/libratbag/libratbag/blob/master/src/hidpp20.h)：灯效 ID、RGB 及周期字段。
- [Solaar onboard profile capabilities](https://github.com/pwr-Solaar/Solaar/blob/master/docs/capabilities.md)：正常和省电时分别使用不同灯效组。

实现为本地独立序列化代码，没有新增第三方运行依赖。当前范围为格式 5 的 G502 X PLUS 板载配置，不实现实时软件 RGB 控制、动画上传或闲置时间编辑。

2026-10-26 对当前连接设备进行了只读检查：格式 5、255 字节扇区；0x8071 报告的灯效 ID 为 0、1、10、3，与四个可编辑灯效一致。自动测试使用模拟 Flash，没有自动写入真实设备；实际灯效需由用户保存后验证。
