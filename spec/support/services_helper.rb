def stub_github_service
  double("Github service").tap do |github|
    allow(GithubService).to receive(:call).and_yield(github)
  end
end

def stub_github_prs(*prs)
  prs.flatten!
  prs.collect! { |i| double("Github PR #{i}", :number => i) } if prs.first.kind_of?(Numeric)

  expect(NewGithubService).to receive(:pull_requests).and_return(prs)
end
