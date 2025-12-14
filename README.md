# SSRenderer
Processing4.3で制作したレンダラー

[Release](https://github.com/Asynchronous-0x4C/SSRenderer/releases)から.exeファイルをダウンロードできます。

パストレーサーの実装は[こちら](https://github.com/Asynchronous-0x4C/SSRenderer/blob/main/data/PathTracing.fs)

## How to use
Windowsの場合、[Release](https://github.com/Asynchronous-0x4C/SSRenderer/releases)にある.exeを実行することができます。

そうでない場合はスケッチの開き方を参考に頑張ってください。

## Open sketch
スケッチの開き方

1. Processingをダウンロード
2. ライブラリを追加(jar-download.comがおすすめ)
   1. [imageio-hdr](https://jar-download.com/artifact-search/imageio-hdr)
   2. [JOML](https://jar-download.com/artifacts/org.joml)
   3. [Obj](https://github.com/javagl/Obj)
   4. [jglTF](https://jar-download.com/artifact-search/jgltf-model)
   5. [ode4j](https://jar-download.com/artifacts/org.ode4j/core)
   6. [SSGUI](./lib/SSGUI.jar)
3. Processingに同梱されているJDKをJava23に入れ替える
4. Processingの設定画面からアクセスできるpreferences.txtの`run.options=`を`run.options=--enable-preview`に変更
5. メインメモリの割り当てを出来るだけ増やす
6. スケッチを実行

### Caution
レンダラーの実行にあたり、

- Intel Core i7
- GeForce RTX 3060

クラス以上のマシンを推奨します。

## Load models
1. 適当な`.glb`ファイルを用意(8万ポリゴンが限界)
2. `./data/`以下に配置
3. 後述するシーンファイルの記法を参考に、シーンの設定を記述
4. settings.jsonの`scene`プロパティから読み込むシーンファイルを参照
5. レンダラーを起動すると、指定したシーンが読み込まれる

## Scene file
シーンファイルの記法(modelプロパティのみ必須)
```jsonc
{
  "model":"スケッチ又は.exeからのglbファイルへの相対パス",
  "physics":false, //物理演算を利用する場合はtrue
  "renderer":"PathTracer", //PathTracerでパストレーサーを、Rasterizerでラスタライザを指定。ただし、ラスタライザはバグの宝庫なので非推奨。
  "camera":{
    "position":[0.0,1.0,0.0], //物理演算が有効な場合はボディの位置、そうでない場合はカメラの位置
    "rotaiton":[0.0,0.0] //カメラの回転。[横,縦]を度数法で指定するか、またはクォータニオンの4要素を指定可能。
  },
  "reflection":4, //反射(屈折)回数の指定
  "seed":0, //パストレーサーで利用する乱数を生成するシードの設定
  "screenshot":[ //スクリーンショットの設定。上から順に実行される。
    {
      "type":"accum", //通常の蓄積はaccum、Temporal Accumulationを利用する場合はtemporal
      "sample":8 //スクリーンショットを記録するフレーム。typeが切り替わった点からの相対値。
    }
  ]
}
```

## Setting file
設定ファイルの記法(sceneプロパティのみ必須)
```jsonc
{
  "scene":"スケッチ又は.exeからのシーンファイルへの相対パス",
  //あとはシーンファイルと同様の設定が可能。ただし、シーンファイルと重複する設定はシーンファイルの値が採用される。
}
```