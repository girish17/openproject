#!/bin/bash

# OpenProject Docker Deployment Script for feature/boards-community-edition Branch
# This script builds and deploys Docker containers for the boards community edition feature branch

set -e

BRANCH_NAME="feature-boards-community-edition"
PROJECT_NAME="openproject-${BRANCH_NAME}"

echo "🚀 Building OpenProject Docker containers for branch: $BRANCH_NAME"
echo "=================================================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    exit 1
fi

# Build the images
echo "📦 Building backend Docker image..."
docker build -f docker/dev/backend/Dockerfile -t openproject/dev:$BRANCH_NAME .

echo "📦 Building frontend Docker image..."
docker build -f docker/dev/frontend/Dockerfile -t openproject-frontend:$BRANCH_NAME .

# Also tag as latest for compose to use
docker tag openproject/dev:$BRANCH_NAME openproject/dev:latest
docker tag openproject-frontend:$BRANCH_NAME openproject-frontend:latest

echo "✅ Docker images built successfully!"
echo ""

# Show created images
echo "📋 Created Docker images:"
docker images | grep openproject | grep $BRANCH_NAME

echo ""
echo "🎯 Branch-specific features included:"
echo "   - Unlocked all board types for Community Edition"
echo "   - Updated boards module functionality"
echo "   - Frontend board actions and partitioning updates"
echo ""

echo "🌐 To start the services, run:"
echo "   bin/compose up -d backend frontend worker db"
echo ""
echo "📊 To check status:"
echo "   bin/compose ps"
echo ""
echo "📝 To view logs:"
echo "   bin/compose logs -f"
echo ""
echo "🛑 To stop services:"
echo "   bin/compose down"
echo ""
echo "🌍 OpenProject will be available at: http://localhost:3000"
echo "🌍 Frontend dev server at: http://localhost:4200"
echo ""
echo "✨ Deployment ready! The boards community edition features are now available."