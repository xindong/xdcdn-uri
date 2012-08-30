require 'grit'

class XdcdnUri

    attr_accessor :repo
    attr_accessor :trees_hash

    def initialize(repo_dir)
        @repo = Grit::Repo.new(repo_dir)
        @trees_hash = {}
    end

    def index(ref)
        head = @repo.commits(ref, 1)
        return nil if head.size == 0
        root = head.first.tree
        @trees_hash['.'] = root.id
        root.trees.each { |tree| build_path(tree, []) }
        return @trees_hash
    end

    def file(tree, filename)
        blob = @repo.tree(tree) / filename
        return nil if blob.nil?
        { 'bytes' => blob.size, 'mime_type' => blob.mime_type, 'data' => blob.data }
    end

    private

    # 构建 path
    def build_path(tree, parents)
        paths = parents << tree.basename
        @trees_hash[paths.join('/')] = tree.id
        # 继续构建子目录
        tree.trees.each { |t| build_path(t, paths) }
    end

end