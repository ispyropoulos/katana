class Repositories::GitRepository < Repository
  def branches
    #TODO : Raise exception when authentication fails
    branches = `git ls-remote -h #{@url}`

    parse_branches(branches)
  end

  def self.all
    {
      '1' => 'git@github.com:ispyropoulos/katanomeas.git',
      '2' => 'git@github.com:ispyropoulos/katana.git',
      '3' => 'git@github.com:pakallis/incrediblue.git'
    }
  end

  private

  def parse_branches(branches)
    brs = []
    branches = branches.split("\n")
    branches.each do |branch|
      brs << branch.match(/refs\/heads\/.*/)[0].split("/")[2]
    end

    brs
  end
end
