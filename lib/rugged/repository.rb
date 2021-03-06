module Rugged
  # Repository is an interface into a Git repository on-disk. It's the primary
  # interface between your app and the main Git objects Rugged makes available
  # to you.
  class Repository
    # Pretty formatting of a Repository.
    #
    # Returns a very pretty String.
    def inspect
      "#<Rugged::Repository:#{object_id} {path: #{path.inspect}}>"
    end

    # Get the most recent commit from this repo.
    #
    # Returns a Rugged::Commit object.
    def last_commit
      self.lookup self.head.target
    end

    def diff(left, right)
      tree1 = nil
      tree2 = nil

      tree1 = left if left.is_a?(Rugged::Tree)
      tree1 = left.tree if left.is_a?(Rugged::Commit)

      tree2 = right if right.is_a?(Rugged::Tree)
      tree2 = right.tree if right.is_a?(Rugged::Commit)

      raise ArgumentError, "Rugged::Tree or Rugged::Commit expected for left side of diff, got #{left.class.name}" unless tree1.is_a?(Rugged::Tree)
      raise ArgumentError, "Rugged::Tree or Rugged::Commit expected for right side of diff, got #{right.class.name}" unless tree2.is_a?(Rugged::Tree)

      tree1.diff(tree2)
    end

    # Walks over a set of commits using Rugged::Walker.
    #
    # from    - The String SHA1 to push onto Walker to begin our walk.
    # sorting - The sorting order of the commits, as defined in the README.
    # block   - A block that we pass into walker#each.
    #
    # Returns nothing if called with a block, otherwise returns an instance of
    # Enumerable::Enumerator containing Rugged::Commit objects.
    def walk(from, sorting=Rugged::SORT_DATE, &block)
      walker = Rugged::Walker.new(self)
      walker.sorting(sorting)
      walker.push(from)
      walker.each(&block)
    end

    # Find the HEAD of this repository.
    #
    # Returns a Reference.
    def head
      ref = Reference.lookup(self, "HEAD")
      ref.resolve
    end

    # Look up a SHA1.
    #
    # Returns one of the four classes that inherit from Rugged::Object.
    def lookup(oid)
      Rugged::Object.lookup(self, oid)
    end

    # Look up an object by a revision string.
    #
    # Returns one of the four classes that inherit from Rugged::Object.
    def rev_parse(spec)
      Rugged::Object.rev_parse(self, spec)
    end

    # Look up an object by a revision string.
    #
    # Returns the oid of the matched object as a String
    def rev_parse_oid(spec)
      Rugged::Object.rev_parse_oid(self, spec)
    end

    # Look up a single reference by name.
    #
    # Example:
    #
    #   repo.ref 'refs/heads/master'
    #   # => #<Rugged::Reference:2199125780 {name: "refs/heads/master",
    #          target: "25b5d3b40c4eadda8098172b26c68cf151109799"}>
    #
    # Returns a Rugged::Reference.
    def ref(ref_name)
      Rugged::Reference.lookup(self, ref_name)
    end

    # Retuns all the References that match a pattern.
    #
    # refs - A Regexp (or String) to search for. Optional.
    #
    # Examples:
    #
    #   # All refs
    #   repo.refs
    #
    #   # All remote refs
    #   repo.refs 'refs/remotes'
    #
    # Returns an Array of References.
    def refs(pattern = nil)
      r = []
      ref_names.each do |ref_name|
        if pattern
          p = Regexp.new(pattern)
          r << Rugged::Reference.lookup(self, ref_name) if p.match(ref_name)
        else
          r << Rugged::Reference.lookup(self, ref_name)
        end
      end
      r
    end

    # The names of all the refs.
    #
    # Returns an Enumerable::Enumerator containing all the String ref names.
    def ref_names
      Rugged::Reference.each(self)
    end

    # All the tags in the repository.
    #
    # Returns an Enumerable::Enumerator containing all the String tag names.
    def tags(pattern="")
      Rugged::Tag.each(self, pattern)
    end

    # All the remotes in the repository.
    #
    # Returns an Enumerable::Enumerator containing all the Rugged::Remotes in
    # the repository.
    def remotes
      Rugged::Remote.each(self)
    end

    # All the branches in the repository
    #
    # Returns an Enumerable::Enumerator containing Rugged::Branch objects
    def branches
      Rugged::Branch.each(self)
    end

    # Create a new branch in the repository
    #
    # name - The name of the branch (without a full reference path)
    # sha_or_ref - The target of the branch; either a String representing
    # an OID or a reference name, or a Rugged::Object instance.
    #
    # Returns a Rugged::Branch object
    def create_branch(name, sha_or_ref = "HEAD")
      case sha_or_ref
      when Rugged::Object
        target = sha_or_ref.oid
      else
        target = rev_parse_oid(sha_or_ref)
      end

      Branch.create(self, name, target)
    end

    # Get the blob at a path for a specific revision.
    #
    # revision - The String SHA1.
    # path     - The String file path.
    #
    # Returns a String.
    def blob_at(revision, path)
      tree = Rugged::Commit.lookup(self, revision).tree
      begin
        blob_data = tree.path(path)
      rescue Rugged::TreeError
        return nil
      end
      blob = Rugged::Blob.lookup(self, blob_data[:oid])
      (blob.type == :blob) ? blob : nil
    end

    # Add the entry to the repository's index.
    # It iterates over the files under and adds them if the entry is a directory.
    #
    # entry - The String path.
    #
    # Returns nothing.
    def add(entry)
      real_entry = File.join(workdir, entry)
      if File.directory?(real_entry)
        Dir.glob(File.join(real_entry, '*')).each do |file|
          relative_file = File.expand_path(file).sub(/^#{workdir}/, '')
          add(relative_file)
        end
      else
        index.add(entry)
      end
    end
  end
end
