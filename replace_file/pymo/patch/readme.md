源代码仓库：[Strrationalism/CPyMO: PyMO AVG Game Engine implemention in C.](https://github.com/Strrationalism/CPyMO)

1. ``git clone https://github.com/Strrationalism/CPyMO``
2. ``cd CPyMO``
3. ``git submodule update --init --recursive``
4. ``patch -p1 < cpymo-patch-0001-support-arkos.patch``
5. ``cd cpymo-backends/sdl2/``
6. ``make``

按键说明
|    功能               |       按键                     |
| ----------------- | --------------------------- |
| 上 / 下 / 左 / 右 | 十字键 / 左摇杆 / 右摇杆    |
| 确认（OK）        | **A / X**                   |
| 隐藏窗口          | **B / Y**                   |
| 单步快进          | **L / R**                   |
| 连续快进（按住）  | **L / R**                   |
| 自动快进切换      | **L2 / R2（点按）**         |
| 关闭自动快进      | 再次点按 **L2 / R2**        |
| 立即退出          | **START + SELECT 同时按下** |

| Function                          | Button                                                 |
| ----------------------------------------- | ------------------------------------------------------------ |
| Up / Down / Left / Right | D-Pad / Left Stick / Right Stick          |
| Confirm / OK                    | **A / X**                                                    |
| Hide Window                       | **B / Y**                                                    |
| Step Skip                         | **L / R**                                                    |
| Continuous Skip (Hold)        | **L / R**                                                    |
| Toggle Auto Skip                | **L2 / R2 (Tap)**                                            |
| Disable Auto Skip               | Tap **L2 / R2** again                    |
| Immediate Exit                    | Press **START + SELECT** together |

