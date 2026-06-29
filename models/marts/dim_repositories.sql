WITH repositories AS (
    SELECT * FROM {{ ref('stg_repositories') }}
)

SELECT
    repository_id,
    repository_name,
    full_name,
    owner_username,
    description,
    language,
    stars,
    forks,
    open_issues,
    created_at AS repo_created_at,
    updated_at AS repo_updated_at,
    pushed_at AS last_push_at
FROM repositories