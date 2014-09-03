Nihonshu
========================================



概要
----------------------------------------

Wine を日本語環境の OS X 向けにカスタマイズするプロジェクトです。作者の個人的な仕様変更が含まれています。



特徴
----------------------------------------

-   __Xcode や MacPorts、Homebrew などの準備が不要__

    アーカイブを解凍するだけで使えます。（でも、もしかしたら不足しているライブラリがあるかもしれません）

-   __日本語環境用初期設定 INF を同梱__

    面倒なフォント設定などが簡単に設定できる INF を同梱しています。

-   __OS X メニューバーが自動で隠れる__

    Windows アプリケーションのウィンドウがアクティブなときに OS X のメニューバーが自動で非表示なるので上 22px 分若干広く使えます。また、Wine のメニュー項目の表記を日本語に変更しています。

-   __Command キーと Option キーの配置が逆__

    Windows の Alt キーが Option キーになるようにキーの配置を変更しています。また、アプリケーションの終了を Command+Option+Q から一般的な OS X アプリケーションと同じ Command+Q に変更しています。

-   __地域情報を『日本』に変更__

    言語だけではなく地域情報を『日本』に変更しています。日本語版 Windows 限定のアプリケーションも動くらしい？（＊タイムゾーン情報の設定に付属の INF のインストールが必要です）

-   __Wine エクスプローラのデフォルトウィンドウサイズが大きい__

    Wine エクスプローラのウィンドウサイズを 800×600 に変更しています。また、フォルダアイコンが水色ではなく黄色になっています。

変更点の詳細は[パッチ](https://github.com/mattintosh4/compact-wine/tree/master/patch_archive)を参照してください。



ダウンロード
----------------------------------------

以下のページにて配布しています。

http://matome.naver.jp/odai/2140238022377155001



インストール・アンインストール
----------------------------------------

Finder 等でアーカイブを適当な場所に解凍してください。理想は `/usr/local` ですが、アクセス権等がよくわからない場合はホームディレクトリでもかまいません。アーカイブ内のルートディレクトリ名は `wine` ですので上書き等にご注意ください。

以下、`/usr/local` に解凍したものとして説明します。

2014年09月現在、`nihonshu` コマンドを使用した場合のみ拡張 INF のインストールが行われます。

```sh
/usr/local/wine/bin/nihonshu program.exe
```

アンインストールは解凍したディレクトリを削除するだけです。Wine が生成するファイルのアンインストールに関しては Wine 公式 Wiki に掲載されていますのでそちらを参照してください。

20140902 では `nihonshu` コマンドを使用した場合のキャッシュフォルダが変更になりました。（注：この配置には誤りがあったため近日修正します）

|環境変数|パス|
|:--|:--|
|XDG\_CACHE\_HOME|$HOME/Library/Caches/Wine|
|XDG\_CONFIG\_HOME|$HOME/Library/Caches/Wine|
|XDG\_DATA\_HOME|$HOME/Library/Caches/Wine|



その他留意事項
----------------------------------------

本プログラムは GPLv3 のもとで配布されています。問題が生じても製作者は一切の責任を負いません。

ちょくちょく気分で仕様変更していることがあるので注意してください。あと、当方は日常的にプログラミング言語を扱っているわけではありませんので Wine の仕様をごっそり変えるようなことはできません。

「○○が動かない」「○○のインストール方法がわからない」等のご質問には基本的にはお応えしません。Wine の使い方に関してはオリジナルと同じですのでご自分で調べてください。

Windows アプリケーションは本来 Wine で動作するように製作されているわけではありません。正常に動作しなかったとしてもアプリケーションの製作者様への問い合わせ等はご迷惑になりますので絶対にしないでください。

本プログラムは Wine のソースを改変していますので、公式 Wiki へ問い合わせる場合はご自分で Wine をビルドしてください。

<br />

[twitter@mattintosh4](https://twitter.com/mattintosh4)



****************************************

本プログラムには以下のライブラリが含まれています。

-   Little CMS
-   libfreetype
-   libjpeg-turbo
-   liblzma
-   libpng
-   libtiff



****************************************

Copyright (C) 2013-2014  mattintosh4

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see {http://www.gnu.org/licenses/}.
