def stub_github_prs(*prs)
  prs.flatten!
  prs.collect! { |i| double("Github PR #{i}", :number => i) } if prs.first.kind_of?(Numeric)

  expect(NewGithubService).to receive(:pull_requests).and_return(prs)
end
