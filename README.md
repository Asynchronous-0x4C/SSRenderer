# SSRenderer
Processing4.3で制作したレンダラー

## How to use
1. Processingをダウンロード
2. ライブラリを追加(jar-download.comがおすすめ)
   1. [imageio-hdr](https://jar-download.com/artifact-search/imageio-hdr)
   2. [JOML](https://jar-download.com/artifacts/org.joml)
   3. [Obj](https://github.com/javagl/Obj)
   4. [jglTF](https://jar-download.com/artifact-search/jgltf-model)
   5. [ode4j](https://jar-download.com/artifacts/org.ode4j/core)
   6. [SSGUI](./lib/SSGUI.jar)
3. Processingに同梱されているJDKをJava22に入れ替える
4. Processingの設定画面からアクセスできるpreferences.txtの`run.options=`を`run.options=--enable-preview`に変更
5. メインメモリの割り当てを出来るだけ増やす
6. スケッチを実行

### Caution
レイトレーシングを利用する場合、普通に重いので

- Intel Core i7
- GeForce RTX 3060

クラス以上のマシンを推奨します。

## Load models
1. 適当な`.glb`ファイルを用意(5~10万ポリゴンが限界かも)
2. `./data/`以下に配置
3. 77行目辺りを`loadGLTF("/data/path/to/file/",/*File name*/);`に変更

## Rasterizer
SSRenderer.pdeの75行目辺り
```java
renderer=new RayTracer();
```
を
```java
renderer=new Rasterizer();
```
に変えましょう。

残念ながら、動的に切り替えられるだろうという甘えは通用しません。

## RayTracer
[シェーダーへのリンク](./data/PathTracing.fs)

SSRenderer.pdeの75行目辺りを
```java
renderer=new RayTracer();
```
に変えましょう。