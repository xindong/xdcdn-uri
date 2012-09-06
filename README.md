心动游戏CDN资源统一平台
--------------------------------------------

使用 Git 来管理资源文件仓库，优势：

  - 相比 SVN 更新更迅速，除了上传前会预压缩，Git 相同的文件不会重复上传
  - 以照目录名来生成索引，而不是文件，以免文件数量过多导致索引过大
  - 更新大版本无需全部资源重新加载，一个目录下的文件和文件夹没变化，就不会生成新的URL
  - 彻底解决版本号问题，不会加载到旧资源

需要注意的：

  - 将经常会一起更新的文件，放在相同的目录下。 一个目录下即使只是增加一个文件，或者删除一个文件，或者增加一个目录，都会造成当前目录的 tree_id 发生变化，这是 Git 的规则。为了保持 uri.xdcdn.net 的无状态性（不依赖额外的数据库来记录数据），方便分布式部署，暂时没有很好的方式解决。


更新过程：

  1. 切换到相应的分支
  1. 整体删除现有仓库（除了 .git 目录）
  <pre>rm -fr *</pre>
  1. 整体复制目的版本至仓库
  1. 运行脚本，将所有文件的属性改为 0644，所有目录属性改为 0755，以免只因为属性的变化造成 Object / Tree 的 ID 发生改变
  <pre>find . -type f | xargs chmod 0644
  find . -type d | xargs chmod 0755</pre>
  1. 测试 OK 后打标签：git commit && git tag *20120907A* 表示 2012-09-07的第1个版本
  1. 提交标签
  <pre>git push && git push -\-tags</pre>
  1. 检查源服务器更新状态 http://repo.xdcdn.net/status/*<REPO_SLUG>*.xdcdn.net.txt（为安全性考虑，目前仍需要 SVN 的帐号登录，今后改成公司 LDAP 帐号）

调用方法：

  - 索引文件 CDN 缓存 **1小时**：<pre>http://uri.xdcdn.net/*<REPO_SLUG>*/index/*<GIT_TAG>*?proto=1.0</pre>
  - 文件内容 CDN 缓存 **1年**：<pre>http://uri.xdcdn.net/*<REPO_SLUG>*/tree/*<GIT_TREE>*/*<FILE_NAME>*</pre>
  
  索引文件格式：
  
  - 每行一个目录，LF（\\n） 分割，每行有25个字节
  - 前5个字节，以 php 代码：<pre>substr(sha1($dirname, true), 0, 5)</pre> $dirname 为 "abc/def/ghi" 形式，根目录为 "."
  - 后20个字节为 tree_id，转换为 40 字节的 ascii 16进制的字符串，记下

使用方法（以开天辟地为例，REPO_SLUG = *ktk*）：

  1. 完成 *更新过程* 后，在后台更新某个测试服的版本名，填入相应 tag，如 *20120825A*
  1. 网页接口根据后台信息，在页面里输出：
    - cdn_index: "<http://uri.xdcdn.net/ktk/index/20120825A>"
    - cdn_root: "<http://uri.xdcdn.net/ktk/tree/>"
  1. 客户端读取到索引文件，解析后存在一个 Hash/Map 类型变量中，key 为目录名的 sha1 值的前5个字节，值为 40 个字节的 tree_id
  1. 读取资源的函数，将目录名 sha1 后取前 5 个字节，到以上变量中查找相应的 key，然后拼凑下载 URL，如: 
    - 根目录下 Main.swf: <http://uri.xdcdn.net/ktk/tree/6234ab487915f9bf2cd287a67b44481d627001b8dce8e/Main.swf>
    - assets/TeamBossIMG/4257.jpg: <http://uri.xdcdn.net/ktk/tree/f4e0730c657d33c965b838d4052843b9b26075c8/4257.jpg>


