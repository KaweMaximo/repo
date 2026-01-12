import os
import logging
import functions_framework
from datetime import datetime
from github import Github, GithubException

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@functions_framework.http
def daily_commit(request):
    """
    HTTP Cloud Function that performs a daily commit to a GitHub repository.
    Triggered by Cloud Scheduler via HTTP request.
    """
    # Environment variables
    GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')
    REPO_NAME = os.environ.get('REPO_NAME') # Format: 'user/repo'
    FILE_PATH = os.environ.get('LOG_FILE_PATH', 'daily_log.txt')
    
    if not GITHUB_TOKEN or not REPO_NAME:
        logger.error("Missing GITHUB_TOKEN or REPO_NAME environment variables.")
        return "Error: Environment variables not configured.", 500

    try:
        g = Github(GITHUB_TOKEN)
        repo = g.get_repo(REPO_NAME)
        
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        content = f"Contribution log: {now}\n"
        
        try:
            # Try to update the existing file
            contents = repo.get_contents(FILE_PATH)
            repo.update_file(
                path=contents.path,
                message=f"chore: daily contribution {now}",
                content=content,
                sha=contents.sha
            )
            action = "updated"
        except GithubException as e:
            if e.status == 404:
                # File doesn't exist, create it
                repo.create_file(
                    path=FILE_PATH,
                    message=f"chore: initial contribution {now}",
                    content=content
                )
                action = "created"
            else:
                raise e
            
        logger.info(f"Successfully {action} {FILE_PATH} at {now}.")
        return f"Success: {FILE_PATH} {action} at {now}.", 200

    except Exception as e:
        logger.error(f"GitHub operation failed: {str(e)}")
        return f"Error: {str(e)}", 500