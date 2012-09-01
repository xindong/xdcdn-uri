require 'grit'

module Chandy

    class Repo

        attr_accessor :repo
        attr_accessor :trees_hash

        def initialize(repo_dir)
            begin
                @repo = Grit::Repo.new(repo_dir)
            rescue => e
                raise Chandy::Error, e.message
            end
            @trees_hash = {}
        end

        def index(ref)
            root = root_tree_of(ref)
            @trees_hash['.'] = root.id
            root.trees.each { |tree| build_path(tree, []) }
            return @trees_hash
        end

        def file(tree, filename)
            blob = @repo.tree(tree) / filename
            raise Chandy::NotFound if blob.nil?
            { 'bytes' => blob.size, 'mime_type' => blob.mime_type, 'data' => blob.data }
        end

        def all(ref)
            root = head.first.tree

        end

        private

        def root_tree_of(ref)
            head = @repo.commits(ref, 1)
            raise Chandy::NotFound, "#{ref} not found" if head.size == 0
            return head.first.tree
        end

        # 构建 path
        def build_path(tree, parents)
            paths = parents << tree.basename
            @trees_hash[paths.join('/')] = tree.id
            # 继续构建子目录
            tree.trees.each { |t| build_path(t, paths) }
        end

    end

    class Error < StandardError
        attr_reader :reason
        def initialize(reason)
            @reason = reason
        end
    end

    class NotFound < StandardError
        attr_reader :reason
        def initialize(reason)
            @reason = reason
        end
    end
end
