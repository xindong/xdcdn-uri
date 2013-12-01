require 'grit'

Grit::Git.git_timeout = 60
Grit::Git.git_max_size = 104857600

module Chandy

    class Repo

        attr_accessor :repo
        attr_accessor :trees_hash

        def initialize(repo_dir)
            begin
                @repo = File.basename(repo_dir)
                @grit = Grit::Repo.new(repo_dir)
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

        def file(args)
            blob = nil
            if args.has_key? :blob_id
                blob = @grit.blob(args[:blob_id])
                raise Chandy::NotFound, "#{@repo} / blob: #{args[:blob_id]} not found" if blob.nil?
            elsif args.has_key? :tree_id and args.has_key? :filename
                blob = @grit.tree(args[:tree_id]) / args[:filename]
                raise Chandy::NotFound, "#{@repo} / #{args[:tree_id]}/#{args[:filename]} not found" if blob.nil?
            elsif args.has_key? :tag and args.has_key? :path
                blob = root_tree_of(args[:tag]) / args[:path]
                raise Chandy::NotFound, "#{@repo} / #{args[:path]}@#{args[:tag]} not found" if blob.nil?
            else
                raise Chandy::NotFound, "invalid args"
            end
            { 'bytes' => blob.size, 'mime_type' => blob.mime_type, 'data' => blob.data }
        end

        def diff(tag1, tag2)
            [tag1, tag2].each do |ref|
                head = @grit.commits(ref, 1)
                raise Chandy::NotFound, "#{@repo} / ref: #{ref} not found" if head.size == 0
            end
            diffs = []
            native_diff(tag1, tag2).each do |diff|
                next if diff.b_path.nil? or diff.b_blob.nil? or diff.b_blob.id.nil?
                diffs << [diff.b_path, diff.b_blob.id]
            end
            return diffs
        end

        def all_blobs(ref)
            blobs = {}
            index(ref).each do |dir, tid|
                @grit.tree(tid).blobs.each { |b| blobs["#{dir}/#{b.basename}"] = b.id }
            end
            return blobs
        end

        def grit
            @grit
        end

        private

        def root_tree_of(ref)
            head = @grit.commits(ref, 1)
            raise Chandy::NotFound, "#{@repo} / ref: #{ref} not found" if head.size == 0
            return head.first.tree
        end

        # 构建 path
        def build_path(tree, parents)
            paths = parents << tree.basename
            @trees_hash[paths.join('/')] = tree.id
            # 继续构建子目录
            tree.trees.each { |t| build_path(t, paths.clone) }
        end

        def native_diff(a, b, *paths)
            diff = @grit.git.native('diff', {}, a, b, '--full-index', *paths)
            if diff =~ /diff --git a/
                diff = diff.sub(/.*?(diff --git a)/m, '\1')
            else
                diff = ''
            end
            Grit::Diff.list_from_string(@grit, diff)
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
