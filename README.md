# 🚀 AWS DevOps Real-Time Deployment | Dev → Pre-PROD → Production  

![AWS DevOps](https://img.shields.io/badge/AWS-DevOps-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)
![CI/CD](https://img.shields.io/badge/CI%2FCD-Pipeline-blue?style=for-the-badge&logo=github-actions&logoColor=white)
![Nginx](https://img.shields.io/badge/Web%20Server-Nginx-green?style=for-the-badge&logo=nginx&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-2.0-brightgreen?style=for-the-badge)

![AWS DevOps](https://imgur.com/YlMBIaa.png)  

## 📌 Overview  

This repository demonstrates a **real-time AWS DevOps deployment pipeline** designed to streamline application releases across three environments:  

- **Development (Dev)** – Continuous integration and testing  
- **Pre-Production (Pre-PROD)** – Staging for validation and QA  
- **Production** – Final deployment for end users  

By leveraging AWS services and modern DevOps tools, this setup ensures a seamless, automated, and scalable CI/CD workflow.

---

## 🏗️ Features & Tech Stack  

### 🚀 **Core Technologies**
✅ **Infrastructure as Code (IaC)** – Terraform & AWS CloudFormation  
✅ **Version Control & Source Code Management** – GitHub/Azure DevOps  
✅ **CI/CD Pipeline** – AWS CodePipeline & Jenkins  
✅ **Containerization & Orchestration** – Docker & Kubernetes (EKS)  
✅ **Monitoring & Logging** – AWS CloudWatch & Prometheus  
✅ **Security & Compliance** – IAM, AWS Secrets Manager, and best DevSecOps practices  

### 🆕 **Version 2.0 Enhancements**
✅ **Enhanced Security** – Security headers, rate limiting, and SSL/TLS configuration  
✅ **Performance Optimization** – Caching strategies, gzip compression, and asset optimization  
✅ **Better Error Handling** – Retry logic, comprehensive logging, and graceful failure recovery  
✅ **Environment Management** – Separate configurations for dev, staging, and production  
✅ **Monitoring & Alerting** – Health checks, performance metrics, and automated alerts  
✅ **Accessibility Improvements** – Semantic HTML5, ARIA labels, and keyboard navigation  

### 📋 **Project Structure**
```
├── appspec.yml              # AWS CodeDeploy application specification (v2.0)
├── buildspec.yml            # AWS CodeBuild build specification (v2.0)
├── index.html               # Main application file (enhanced)
├── nginx-security.conf      # Nginx security hardening configuration
├── environments/            # Environment-specific configurations
│   ├── dev.env             # Development environment settings
│   ├── staging.env         # Staging environment settings
│   └── prod.env            # Production environment settings
├── scripts/
│   ├── install_nginx.sh    # Nginx installation script (v2.0)
│   ├── start_nginx.sh       # Nginx startup script (v2.0)
│   ├── validate_environment.sh  # Environment validation
│   ├── validate_deployment.sh   # Deployment validation
│   └── load_environment_config.sh # Environment configuration loader
└── README.md               # Project documentation
```

### 🔧 **Scripts Overview**
- **`validate_environment.sh`** - Pre-deployment system validation with enhanced checks
- **`install_nginx.sh`** - Automated Nginx installation with retry logic and security hardening
- **`start_nginx.sh`** - Nginx service management with comprehensive health checks
- **`validate_deployment.sh`** - Post-deployment verification with performance testing
- **`load_environment_config.sh`** - Environment-specific configuration loader

This project is designed to enhance agility, reduce manual interventions, and ensure reliable software delivery.

---

## 🚀 Quick Start

### Prerequisites
- AWS Account with appropriate permissions
- AWS CLI configured
- Git installed
- Basic understanding of DevOps concepts

### Deployment Steps
1. **Clone the repository**
   ```bash
   git clone https://github.com/NotHarshhaa/AWS-DevOps_Real-Time_Deployment.git
   cd AWS-DevOps_Real-Time_Deployment
   ```

2. **Configure AWS CodeDeploy**
   - Set up CodeDeploy application
   - Configure deployment groups
   - Update `appspec.yml` if needed

3. **Deploy the application**
   - Trigger deployment through AWS Console
   - Monitor deployment logs
   - Verify application is running

### 🧪 **Testing**
The deployment includes comprehensive testing:
- Environment validation
- Service health checks
- HTTP response testing
- Content delivery verification
- Performance testing
- Security header validation

---

## 📖 Step-by-Step Guide  

For a complete walkthrough with **detailed screenshots**, visit the blog post:  
📌 [AWS DevOps Real-Time Deployment – Full Guide](https://blog.prodevopsguytech.com/aws-devops-real-time-deployment-dev-pre-prod-production)  

---

## 🔍 **Monitoring & Logging**

### Log Files
- `/var/log/nginx-install.log` - Nginx installation logs
- `/var/log/nginx-start.log` - Nginx startup logs
- `/var/log/environment-validation.log` - Environment validation logs
- `/var/log/environment-config.log` - Environment configuration logs

### Health Checks
- Service status monitoring
- HTTP response validation
- Content delivery verification
- System resource monitoring
- Performance metrics collection

### Security Features
- Security headers implementation
- Rate limiting configuration
- SSL/TLS hardening
- File permission restrictions
- Access control policies

---

## 🛠️ Configuration Management

### Environment-Specific Settings
The project supports three environments with distinct configurations:

#### Development Environment
- Debug mode enabled
- Relaxed security settings
- Enhanced logging
- Development tools enabled

#### Staging Environment
- Production-like settings
- Moderate security
- Comprehensive testing tools
- Performance monitoring

#### Production Environment
- Maximum security
- Optimized performance
- Minimal logging
- Monitoring and alerting

### Loading Environment Configuration
```bash
# Load development configuration
./scripts/load_environment_config.sh dev

# Load staging configuration
./scripts/load_environment_config.sh staging

# Load production configuration
./scripts/load_environment_config.sh prod
```

---

## 🤝 Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Guidelines
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Quality Standards
- Follow shell scripting best practices
- Add comprehensive error handling
- Include logging for debugging
- Test across all environments
- Document new features

---

## 🛠️ Author & Credits

![text](https://imgur.com/2j7GSPs.png)

This project is built and maintained by **[Harshhaa](https://github.com/NotHarshhaa)** 💡.  
Feel free to contribute, suggest improvements, or reach out for discussions!  

### 📧 **Contact & Links**
- **GitHub**: [@NotHarshhaa](https://github.com/NotHarshhaa)
- **Blog**: [Hashnode](https://blog.prodevopsguy.xyz)
- **LinkedIn**: [Connect with me](https://linkedin.com/in/harshhaa)

### 🔖 **License**
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📊 **Project Stats**

![GitHub stars](https://img.shields.io/github/stars/NotHarshhaa/AWS-DevOps_Real-Time_Deployment?style=social)
![GitHub forks](https://img.shields.io/github/forks/NotHarshhaa/AWS-DevOps_Real-Time_Deployment?style=social)
![GitHub issues](https://img.shields.io/github/issues/NotHarshhaa/AWS-DevOps_Real-Time_Deployment)
![GitHub last commit](https://img.shields.io/github/last-commit/NotHarshhaa/AWS-DevOps_Real-Time_Deployment)

---

## 🙏 **Acknowledgments**

- AWS for providing excellent cloud services
- The DevOps community for continuous learning and support
- All contributors who help improve this project
- Security experts for best practices and guidelines

---

## 📋 **Changelog**

### Version 2.0 (Current)
- ✨ Enhanced security headers and SSL/TLS configuration
- ✨ Environment-specific configuration management
- ✨ Improved error handling and retry logic
- ✨ Performance optimizations and caching
- ✨ Accessibility improvements in HTML
- ✨ Comprehensive monitoring and logging
- ✨ Build caching and optimization

### Version 1.0
- 🎉 Initial release with basic CI/CD pipeline
- 🎉 Nginx installation and configuration
- 🎉 Basic deployment validation

---

<div align="center">
  <strong>⭐ Star this repository if you found it helpful! ⭐</strong>
</div>
