function create-branch() {
  # The function expectes that username and password are stored using secret-tool.
  # To store these, use
  # secret-tool store --label="JIRA username" jira username
  # secret-tool store --label="JIRA password" jira password

  # local jq_template query username password branch_name
  local jq_template jira_project_key jira_base_url query personal_access_token branch_name

  #jira_project_key="DEVOPS"
  jira_project_key="CONNECT"
  jira_base_url="https://dev.prusa3d.com"
  jq_template='"'\
'\(.key). \(.fields.summary)'\
'\t'\
'Reporter: \(.fields.reporter.displayName)\n'\
'Created: \(.fields.created)\n'\
'Updated: \(.fields.updated)\n\n'\
'\(.fields.description)'\
'"'
  query="project=${jira_project_key} AND status=\"In Progress\" AND assignee=currentUser()"
#   username=$(secret-tool lookup jira username)
  personal_access_token=$(op item get "fzf workflow jira personal access token" --fields label=credential --vault Prusa)

  branch_name=$(
    curl \
      --data-urlencode "jql=$query" \
      --get \
      --header "Authorization: Bearer ${personal_access_token}" \
      --silent \
      --compressed \
      "${jira_base_url}/rest/api/2/search" |
    jq ".issues[] | $jq_template" |
    gsed -e 's/"\(.*\)"/\1/' -e 's/\\t/\t/' |
    fzf \
      --with-nth=1 \
      --delimiter='\t' \
      --preview='echo -e {2}' \
      --preview-window=top:wrap |
    cut -f1 |
    gsed -e 's/\. /\t/' -e 's/[^a-zA-Z0-9\t]/-/g' |
    awk '{printf "%s/%s", $1, tolower($2)}'
  )

  if [ -n "$branch_name" ]; then
    git checkout -b "$branch_name"
  fi
}
