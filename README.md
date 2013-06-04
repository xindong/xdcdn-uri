心动游戏CDN资源统一平台
--------------------------------------------

使用 Git 来管理资源文件仓库，优势：

  - 相比 SVN 更新更迅速，除了上传前会预压缩，Git 相同的文件不会重复上传
  - 以照目录名来生成索引，而不是文件，以免文件数量过多导致索引过大
  - 更新大版本无需全部资源重新加载，一个目录下的文件和文件夹没变化，就不会生成新的URL
  - 彻底解决版本号问题，不会（无法）加载到旧资源

需要注意的：

  - 将经常会一起更新的文件，放在相同的目录下。 一个目录下即使只是增加一个文件，或者删除一个文件，或者增加一个目录，都会造成当前目录的 tree_id 发生变化，这是 Git 的规则。为了保持 uri.xdcdn.net 的无状态性（不依赖额外的数据库来记录数据），方便分布式部署，暂时没有很好的方式解决。


更新过程：

  1. 切换到相应的分支
  2. 整体删除现有仓库（除了 .git 目录）
  <pre>rm -fr *</pre>
  3. 整体复制目的版本至仓库
  4. 运行脚本，将所有文件的属性改为 0644，所有目录属性改为 0755，以免只因为属性的变化造成 Object / Tree 的 ID 发生改变
  <pre>find . -type f | xargs chmod 0644
  find . -type d | xargs chmod 0755</pre>
  5. 测试 OK 后打标签：git commit && git tag *20120907A* 表示 2012-09-07的第1个版本
  6. 提交标签
  <pre>git push && git push -\-tags</pre>

接口：

  - 索引文件（CDN 缓存 **1小时**）：
    - <pre>http://uri.xdcdn.net/REPO_SLUG/index/GIT_TAG</pre>
    - <pre>http://uri.xdcdn.net/REPO_SLUG/diff/GIT_TAG_1..GIT_TAG_2</pre>
  - 文件内容（CDN 缓存 **1年**）：
    - <pre>http://uri.xdcdn.net/REPO_SLUG/tree/GIT_TREE/FILE_NAME</pre>
    - <pre>http://uri.xdcdn.net/REPO_SLUG/file/BLOB_ID/FILE_NAME</pre>
    - <pre>http://uri.xdcdn.net/REPO_SLUG/load/GIT_TAG/PATH_TO_FILE</pre>
  - 预加载文件列表：
    - <pre>http://uri.xdcdn.net/REPO_SLUG/preload/GIT_TAG</pre>
  - 内网地址：用 uri.xindong.com 代替 uri.xdcdn.net 进行测试
  
  索引文件格式：
  
  - 每25个字节为一段
  - 每段前5个字节，以 php 代码：<pre>substr(sha1($dirname, true), 0, 5)</pre> $dirname 为 "abc/def/ghi" 形式，根目录为 "."
  - 后20个字节为 tree_id（index 协议） 或 blob_id（diff 协议），转换为 40 字节的 ascii 16进制的字符串，记下

使用方法（以开天辟地为例，REPO_SLUG = *ktk*）：

  1. 完成 *更新过程* 后，在后台更新某个测试服的版本名，填入相应 tag，如 *20120825A*
  2. 网页接口根据后台信息，在页面里输出：
    - cdn_root: "<http://uri.xdcdn.net/ktk/>"
    - base_tag: "20120825A"
    - last_tag: "20130604C"
  3. 客户端拼凑2个索引文件 URL（索引文件 CDN 缓存 **1小时**）
    - http://uri.xdcdn.net/ktk/index/20120825A
    - http://uri.xdcdn.net/ktk/diff/20130604C
  4. 加载这2个索引文件，分别解析后存在2个 Hash 类型变量中，其中
    - $idxHash: 将加载到的 http://uri.xdcdn.net/ktk/index/20120825A 的数据以25个字节为一组切开，前5个字节为键名，后20个字节为键值
    - $dffHash: 将加载到的 http://uri.xdcdn.net/ktk/diff/20130604C 的数据以25个字节为一组切开，前5个字节为键名，后20个字节为键值
  5. 封装读取资源的接口，以如下方式拼凑 URL（假设需要加载 assets/TeamBossIMG/4257.jpg ）
    1. $key = substr(sha1('assets/TeamBossIMG/4257.jpg', true), 0, 5); 用 $key 到 $dffHash 里查找是否有对应的键值 $val
    2. 如果有，则直接拼凑下载地址 http://uri.xdcdn.net/ktk/file/$val/4257.jpg
    3. 如果没，则 $key = substr(sha1(dirname('assets/TeamBossIMG/4257.jpg'), true), 0, 5); 用 $key 到 $idxHash 里查找是否有对应的键值 $val，没有则出错了，有的话拼凑下载地址 http://uri.xdcdn.net/ktk/tree/$val/4257.jpg
    4. 如果是根目录下文件，目录名取 '.'，$key = substr(sha1('.', true), 0, 5)，如根目录下 Main.swf: <http://uri.xdcdn.net/ktk/tree/6234ab487915f9bf2cd287a67b44481d627001b8dce8e/Main.swf>

