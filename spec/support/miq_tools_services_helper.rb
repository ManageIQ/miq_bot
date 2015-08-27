def stub_git_service
  double("MiniGit service").tap do |git|
    allow(MiqToolsServices::MiniGit).to receive(:call).and_yield(git)
  end
end

def stub_github_service
  double("Github service").tap do |github|
    allow(MiqToolsServices::Github).to receive(:call).and_yield(github)
  end
end
