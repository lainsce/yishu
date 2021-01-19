# ![icon](data/icon.png) Yishu (艺术)

## A bespoke and simple Todo.txt client

[![Get it on AppCenter](https://appcenter.elementary.io/badge.svg)](https://appcenter.elementary.io/com.github.lainsce.yishu)

[![Build Status](https://travis-ci.org/lainsce/yishu.svg?branch=master)](https://travis-ci.org/lainsce/yishu)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](http://www.gnu.org/licenses/gpl-3.0)

![Screenshot](data/shot.png)

## Donations

Would you like to support the development of this app to new heights? Then:

[Be my backer on Patreon](https://www.patreon.com/lainsce)

## Dependencies

Please make sure you have these dependencies first before building.

```bash
granite
gtk+-3.0
meson
libhandy-1
```

## Building

Simply clone this repo, then:

```bash
meson build && cd build
meson configure -Dprefix=/usr
sudo ninja install
```
