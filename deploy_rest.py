#!/usr/bin/env python3
"""
Microsoft Sentinel Deployment using Azure REST API

This script deploys Microsoft Sentinel workspace and associated content using
Azure REST API instead of Azure CLI commands. It uses the same BICEP templates
but deploys them through direct REST API calls.

Content deployed includes:
- Analytical Rules
- Parsers
- Workbooks
- Hunting Queries (Advanced Hunting)
- Watchlists
"""

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Dict, Any, Optional
import subprocess
import requests
from azure.identity import DefaultAzureCredential, AzureCliCredential
from azure.core.exceptions import ClientAuthenticationError


class Colors:
    """ANSI color codes for terminal output"""
    CYAN = '\033[0;36m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color


class AzureRestDeployer:
    """Azure REST API deployment handler for Sentinel"""
    
    API_VERSION_RESOURCES = "2021-04-01"
    API_VERSION_DEPLOYMENTS = "2021-04-01"
    
    def __init__(self, subscription_id: str, verbose: bool = False):
        """
        Initialize the Azure REST API deployer
        
        Args:
            subscription_id: Azure subscription ID
            verbose: Enable verbose logging
        """
        self.subscription_id = subscription_id
        self.verbose = verbose
        self.access_token = None
        self.credential = None
        
    def authenticate(self) -> bool:
        """
        Authenticate with Azure using DefaultAzureCredential
        
        Returns:
            bool: True if authentication successful, False otherwise
        """
        print(f"{Colors.YELLOW}Authenticating with Azure...{Colors.NC}")
        
        try:
            # Try Azure CLI credential first (most common for local development)
            try:
                self.credential = AzureCliCredential()
                token = self.credential.get_token("https://management.azure.com/.default")
                self.access_token = token.token
                print(f"{Colors.GREEN}✓ Authenticated using Azure CLI credentials{Colors.NC}")
                return True
            except ClientAuthenticationError:
                # Fall back to DefaultAzureCredential (supports managed identity, env vars, etc.)
                self.credential = DefaultAzureCredential()
                token = self.credential.get_token("https://management.azure.com/.default")
                self.access_token = token.token
                print(f"{Colors.GREEN}✓ Authenticated using default credentials{Colors.NC}")
                return True
                
        except Exception as e:
            print(f"{Colors.RED}✗ Authentication failed: {str(e)}{Colors.NC}")
            print(f"{Colors.RED}Please run 'az login' first or set up appropriate credentials{Colors.NC}")
            return False
    
    def _get_headers(self) -> Dict[str, str]:
        """Get HTTP headers with authentication token"""
        return {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json"
        }
    
    def get_subscription_info(self) -> Optional[Dict[str, Any]]:
        """
        Get subscription information
        
        Returns:
            Dict with subscription info or None if failed
        """
        url = f"https://management.azure.com/subscriptions/{self.subscription_id}?api-version={self.API_VERSION_RESOURCES}"
        
        try:
            response = requests.get(url, headers=self._get_headers())
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}✗ Failed to get subscription info: {str(e)}{Colors.NC}")
            return None
    
    def check_resource_group_exists(self, resource_group_name: str) -> bool:
        """
        Check if resource group exists
        
        Args:
            resource_group_name: Name of the resource group
            
        Returns:
            bool: True if exists, False otherwise
        """
        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourcegroups/{resource_group_name}?api-version={self.API_VERSION_RESOURCES}"
        
        try:
            response = requests.get(url, headers=self._get_headers())
            return response.status_code == 200
        except requests.exceptions.RequestException:
            return False
    
    def create_resource_group(self, resource_group_name: str, location: str) -> bool:
        """
        Create a resource group using REST API
        
        Args:
            resource_group_name: Name of the resource group
            location: Azure region
            
        Returns:
            bool: True if successful, False otherwise
        """
        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourcegroups/{resource_group_name}?api-version={self.API_VERSION_RESOURCES}"
        
        body = {
            "location": location
        }
        
        try:
            response = requests.put(url, headers=self._get_headers(), json=body)
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}✗ Failed to create resource group: {str(e)}{Colors.NC}")
            if self.verbose and hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
            return False
    
    def compile_bicep(self, bicep_file: Path) -> Optional[Dict[str, Any]]:
        """
        Compile BICEP file to ARM template using Azure CLI
        
        Args:
            bicep_file: Path to BICEP file
            
        Returns:
            Dict with ARM template or None if failed
        """
        print(f"{Colors.YELLOW}Building BICEP template...{Colors.NC}")
        
        try:
            # Use Azure CLI to build bicep (most reliable method)
            result = subprocess.run(
                ["az", "bicep", "build", "--file", str(bicep_file), "--stdout"],
                capture_output=True,
                text=True,
                check=True
            )
            
            template = json.loads(result.stdout)
            print(f"{Colors.GREEN}✓ BICEP template built successfully{Colors.NC}")
            return template
            
        except subprocess.CalledProcessError as e:
            print(f"{Colors.RED}✗ Failed to build BICEP template{Colors.NC}")
            print(f"Error: {e.stderr}")
            return None
        except Exception as e:
            print(f"{Colors.RED}✗ Failed to build BICEP template: {str(e)}{Colors.NC}")
            return None
    
    def validate_deployment(
        self,
        resource_group_name: str,
        template: Dict[str, Any],
        parameters: Dict[str, Any]
    ) -> bool:
        """
        Validate deployment using What-If API
        
        Args:
            resource_group_name: Name of the resource group
            template: ARM template
            parameters: Deployment parameters
            
        Returns:
            bool: True if validation successful, False otherwise
        """
        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourcegroups/{resource_group_name}/providers/Microsoft.Resources/deployments/validation-{int(time.time())}/whatIf?api-version={self.API_VERSION_DEPLOYMENTS}"
        
        body = {
            "properties": {
                "template": template,
                "parameters": parameters,
                "mode": "Incremental"
            }
        }
        
        try:
            print(f"{Colors.YELLOW}Running deployment validation (What-If)...{Colors.NC}")
            response = requests.post(url, headers=self._get_headers(), json=body)
            response.raise_for_status()
            
            # What-If API is async, so we may need to poll
            if response.status_code == 202:
                location = response.headers.get('Location')
                if location:
                    result = self._poll_async_operation(location)
                    if result:
                        print(f"{Colors.GREEN}✓ Deployment validation successful{Colors.NC}")
                        if self.verbose:
                            print(json.dumps(result, indent=2))
                        return True
            else:
                result = response.json()
                print(f"{Colors.GREEN}✓ Deployment validation successful{Colors.NC}")
                if self.verbose:
                    print(json.dumps(result, indent=2))
                return True
                
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}✗ Deployment validation failed: {str(e)}{Colors.NC}")
            if self.verbose and hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
        
        return False
    
    def deploy_template(
        self,
        resource_group_name: str,
        deployment_name: str,
        template: Dict[str, Any],
        parameters: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        """
        Deploy ARM template using REST API
        
        Args:
            resource_group_name: Name of the resource group
            deployment_name: Name for the deployment
            template: ARM template
            parameters: Deployment parameters
            
        Returns:
            Dict with deployment result or None if failed
        """
        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourcegroups/{resource_group_name}/providers/Microsoft.Resources/deployments/{deployment_name}?api-version={self.API_VERSION_DEPLOYMENTS}"
        
        body = {
            "properties": {
                "template": template,
                "parameters": parameters,
                "mode": "Incremental"
            }
        }
        
        try:
            print(f"{Colors.YELLOW}Starting deployment...{Colors.NC}")
            print(f"{Colors.YELLOW}This may take several minutes...{Colors.NC}")
            
            response = requests.put(url, headers=self._get_headers(), json=body)
            response.raise_for_status()
            
            # Deployment is async, poll for completion
            result = self._poll_deployment(resource_group_name, deployment_name)
            
            if result and result.get('properties', {}).get('provisioningState') == 'Succeeded':
                print(f"\n{Colors.CYAN}====================================={Colors.NC}")
                print(f"{Colors.GREEN}Deployment completed successfully!{Colors.NC}")
                print(f"{Colors.CYAN}====================================={Colors.NC}\n")
                return result
            else:
                print(f"{Colors.RED}✗ Deployment failed{Colors.NC}")
                if result:
                    error = result.get('properties', {}).get('error', {})
                    if error:
                        print(f"Error: {json.dumps(error, indent=2)}")
                return None
                
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}✗ Deployment failed: {str(e)}{Colors.NC}")
            if self.verbose and hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
            return None
    
    def _poll_deployment(self, resource_group_name: str, deployment_name: str, timeout: int = 1800, poll_interval: int = 10) -> Optional[Dict[str, Any]]:
        """
        Poll deployment status until completion
        
        Args:
            resource_group_name: Name of the resource group
            deployment_name: Name of the deployment
            timeout: Timeout in seconds (default 1800 = 30 minutes)
            poll_interval: Seconds between polling attempts (default 10)
            
        Returns:
            Dict with deployment result or None if failed
        """
        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourcegroups/{resource_group_name}/providers/Microsoft.Resources/deployments/{deployment_name}?api-version={self.API_VERSION_DEPLOYMENTS}"
        
        start_time = time.time()
        last_status = None
        
        while time.time() - start_time < timeout:
            try:
                response = requests.get(url, headers=self._get_headers())
                response.raise_for_status()
                result = response.json()
                
                status = result.get('properties', {}).get('provisioningState')
                
                if status != last_status:
                    print(f"{Colors.YELLOW}Deployment status: {status}{Colors.NC}")
                    last_status = status
                
                if status in ['Succeeded', 'Failed', 'Canceled']:
                    return result
                
                time.sleep(poll_interval)
                
            except requests.exceptions.RequestException as e:
                print(f"{Colors.RED}✗ Failed to poll deployment status: {str(e)}{Colors.NC}")
                return None
        
        print(f"{Colors.RED}✗ Deployment timed out after {timeout} seconds{Colors.NC}")
        return None
    
    def _poll_async_operation(self, location_url: str, timeout: int = 300, poll_interval: int = 5) -> Optional[Dict[str, Any]]:
        """
        Poll async operation until completion
        
        Args:
            location_url: URL to poll
            timeout: Timeout in seconds (default 300 = 5 minutes)
            poll_interval: Seconds between polling attempts (default 5)
            
        Returns:
            Dict with operation result or None if failed
        """
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                response = requests.get(location_url, headers=self._get_headers())
                
                if response.status_code == 200:
                    return response.json()
                elif response.status_code == 202:
                    time.sleep(poll_interval)
                else:
                    return None
                    
            except requests.exceptions.RequestException:
                return None
        
        return None
    
    def get_deployment_outputs(self, resource_group_name: str, deployment_name: str) -> Optional[Dict[str, Any]]:
        """
        Get deployment outputs
        
        Args:
            resource_group_name: Name of the resource group
            deployment_name: Name of the deployment
            
        Returns:
            Dict with outputs or None if failed
        """
        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourcegroups/{resource_group_name}/providers/Microsoft.Resources/deployments/{deployment_name}?api-version={self.API_VERSION_DEPLOYMENTS}"
        
        try:
            response = requests.get(url, headers=self._get_headers())
            response.raise_for_status()
            result = response.json()
            return result.get('properties', {}).get('outputs', {})
        except requests.exceptions.RequestException as e:
            print(f"{Colors.RED}✗ Failed to get deployment outputs: {str(e)}{Colors.NC}")
            return None


def load_parameters(parameter_file: Path) -> Optional[Dict[str, Any]]:
    """
    Load parameters from JSON file
    
    Args:
        parameter_file: Path to parameters file
        
    Returns:
        Dict with parameters or None if failed
    """
    try:
        with open(parameter_file, 'r') as f:
            params = json.load(f)
        
        # Convert from ARM parameter file format to deployment format
        if 'parameters' in params:
            return {k: v.get('value') for k, v in params['parameters'].items()}
        else:
            return params
            
    except Exception as e:
        print(f"{Colors.RED}✗ Failed to load parameters: {str(e)}{Colors.NC}")
        return None


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Deploy Microsoft Sentinel using Azure REST API',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -g rg-sentinel-prod -l eastus
  %(prog)s -g rg-sentinel-dev -p parameters.dev.json
  %(prog)s -g rg-sentinel-prod -w
  %(prog)s -g rg-sentinel-prod -s 12345678-1234-1234-1234-123456789012
        """
    )
    
    parser.add_argument('-g', '--resource-group', required=True,
                        help='Azure resource group name')
    parser.add_argument('-l', '--location', default='eastus',
                        help='Azure region (default: eastus)')
    parser.add_argument('-p', '--parameter-file', default='parameters.json',
                        help='Path to parameter file (default: parameters.json)')
    parser.add_argument('-s', '--subscription-id',
                        help='Azure subscription ID (will use default if not provided)')
    parser.add_argument('-w', '--what-if', action='store_true',
                        help='Run in what-if mode (preview changes)')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Enable verbose output')
    
    args = parser.parse_args()
    
    print(f"{Colors.CYAN}====================================={Colors.NC}")
    print(f"{Colors.CYAN}Sentinel REST API Deployment{Colors.NC}")
    print(f"{Colors.CYAN}====================================={Colors.NC}\n")
    
    # Get subscription ID
    subscription_id = args.subscription_id
    if not subscription_id:
        print(f"{Colors.YELLOW}Getting default subscription...{Colors.NC}")
        try:
            result = subprocess.run(
                ["az", "account", "show", "--query", "id", "-o", "tsv"],
                capture_output=True,
                text=True,
                check=True
            )
            subscription_id = result.stdout.strip()
            print(f"{Colors.GREEN}✓ Using subscription: {subscription_id}{Colors.NC}")
        except subprocess.CalledProcessError:
            print(f"{Colors.RED}✗ Failed to get subscription ID. Please specify with -s or run 'az login'{Colors.NC}")
            return 1
    
    # Initialize deployer
    deployer = AzureRestDeployer(subscription_id, verbose=args.verbose)
    
    # Authenticate
    if not deployer.authenticate():
        return 1
    
    # Get subscription info
    sub_info = deployer.get_subscription_info()
    if sub_info:
        print(f"{Colors.GREEN}✓ Subscription: {sub_info.get('displayName', 'Unknown')} ({subscription_id}){Colors.NC}")
    
    # Verify parameter file exists
    parameter_file = Path(args.parameter_file)
    if not parameter_file.exists():
        print(f"{Colors.RED}✗ Parameter file not found: {parameter_file}{Colors.NC}")
        return 1
    print(f"{Colors.GREEN}✓ Using parameter file: {parameter_file}{Colors.NC}")
    
    # Load parameters
    parameters = load_parameters(parameter_file)
    if parameters is None:
        return 1
    
    # Convert parameters to ARM format
    arm_parameters = {k: {"value": v} for k, v in parameters.items()}
    
    # Check resource group
    print(f"\n{Colors.YELLOW}Checking resource group...{Colors.NC}")
    if not deployer.check_resource_group_exists(args.resource_group):
        print(f"{Colors.YELLOW}Creating resource group: {args.resource_group} in {args.location}{Colors.NC}")
        if not deployer.create_resource_group(args.resource_group, args.location):
            return 1
        print(f"{Colors.GREEN}✓ Resource group created{Colors.NC}")
    else:
        print(f"{Colors.GREEN}✓ Resource group exists: {args.resource_group}{Colors.NC}")
    
    # Compile BICEP template
    bicep_file = Path(__file__).parent / "main.bicep"
    if not bicep_file.exists():
        print(f"{Colors.RED}✗ BICEP file not found: {bicep_file}{Colors.NC}")
        return 1
    
    template = deployer.compile_bicep(bicep_file)
    if template is None:
        return 1
    
    # What-if mode or actual deployment
    if args.what_if:
        deployer.validate_deployment(args.resource_group, template, arm_parameters)
    else:
        # Deploy
        deployment_name = f"sentinel-deployment-{int(time.time())}"
        result = deployer.deploy_template(
            args.resource_group,
            deployment_name,
            template,
            arm_parameters
        )
        
        if result:
            # Show outputs
            outputs = deployer.get_deployment_outputs(args.resource_group, deployment_name)
            if outputs:
                print(f"{Colors.CYAN}Deployment outputs:{Colors.NC}")
                for key, value in outputs.items():
                    print(f"  {key}: {value.get('value', 'N/A')}")
            
            print(f"\n{Colors.CYAN}Next steps:{Colors.NC}")
            print("1. Configure data connectors in the Azure Portal")
            print("2. Review and customize analytical rules")
            print("3. Configure automation rules and playbooks")
            print("4. Set up RBAC permissions for your team\n")
            return 0
        else:
            return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
