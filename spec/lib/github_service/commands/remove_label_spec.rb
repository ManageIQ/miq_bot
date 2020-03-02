require 'spec_helper'

RSpec.describe GithubService::Commands::RemoveLabel do
  subject { described_class.new(issue) }
  let(:issue) { double(:fq_repo_name => "foo/bar") }
  let(:command_issuer) { "chessbyte" }
  let(:command_value) { "question, wontfix" }

  after do
    subject.execute!(:issuer => command_issuer, :value => command_value)
  end

  context "with valid labels" do
    before do
      %w(question wontfix).each do |label|
        allow(GithubService).to receive(:valid_label?).with("foo/bar", label).and_return(true)
      end
    end

    context "when the labels are applied" do
      before do
        %w(question wontfix).each do |label|
          expect(issue).to receive(:applied_label?)
            .with(label).and_return(true)
        end
      end

      it "removes the labels" do
        %w(question wontfix).each do |label|
          expect(issue).to receive(:remove_label).with(label)
        end
      end
    end

    context "with some unapplied labels" do
      before do
        expect(issue).to receive(:applied_label?).with("question").and_return(true)
        expect(issue).to receive(:applied_label?).with("wontfix").and_return(false)
      end

      it "only removes the applied label" do
        expect(issue).to receive(:remove_label).with("question")
        expect(issue).not_to receive(:remove_label).with("wontfix")
      end
    end

    context "with labels that are UNREMOVABLE" do
      # An invalid situation, just testing in one go
      let(:command_value) { "wontfix, jansa/no, jansa/yes, jansa/yes?" }

      before do
        %w[wontfix jansa/no jansa/yes jansa/yes?].each do |label|
          allow(GithubService).to receive(:valid_label?).with("foo/bar", label).and_return(true)
        end

        expect(issue).to receive(:applied_label?).with("wontfix").and_return(true)
        expect(issue).to receive(:applied_label?).with("jansa/yes?").and_return(true)

        message = "@chessbyte Cannot remove the following labels since they require "              \
                  "[triage team permissions](https://github.com/orgs/ManageIQ/teams/core-triage)" \
                  ": jansa/no, jansa/yes"

        expect(issue).to receive(:add_comment).with(message)
      end

      it "only removes the applied label" do
        expect(issue).to     receive(:remove_label).with("wontfix")
        expect(issue).not_to receive(:remove_label).with("jansa/no")
        expect(issue).not_to receive(:remove_label).with("jansa/yes")
        expect(issue).to     receive(:remove_label).with("jansa/yes?")
      end
    end
  end
end
