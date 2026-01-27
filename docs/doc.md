# Chat API Documentation

## Overview

The Chat API allows you to interact with an AI assistant that can query your data sources and provide insights.

## Endpoint

```
POST /chat
```

## Authentication

All requests require the following headers:

| Header | Required | Description |
|--------|----------|-------------|
| `x-bluemvmt-tenant-uuid` | ✅ | Your tenant UUID |
| `x-bluemvmt-user-uuid` | ✅ | Your user UUID |

## Request Body

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `input` | string | ✅ | - | The question or prompt to send to the AI |
| `llm_model` | string | ❌ | `"blueai"` | LLM model to use: `"blueai"` or `"gemini-2.5-pro"` |
| `datasource_uuids` | array | ❌ | `null` | List of datasource UUIDs to query against |
| `thread_id` | string | ❌ | `null` | Thread ID for conversation continuity |
| `additional_instructions` | string | ❌ | `null` | Extra instructions for the LLM |

## Response

The API returns a **streaming response** (`text/event-stream`) that delivers the AI's response in real-time.

## Example Request

### Basic Request

```bash
curl -X POST "https://api-staging.isdata.ai/usmcom/data-proxy/chat" \
  -H "Content-Type: application/json" \
  -H "x-bluemvmt-tenant-uuid: YOUR_TENANT_UUID" \
  -H "x-bluemvmt-user-uuid: YOUR_USER_UUID" \
  -d '{
    "input": "What is the total count of records?"
  }'
```

### Request with Datasources

```bash
curl -X POST "https://api-staging.isdata.ai/usmcom/data-proxy/chat" \
  -H "Content-Type: application/json" \
  -H "x-bluemvmt-tenant-uuid: 123e4567-e89b-12d3-a456-426614174000" \
  -H "x-bluemvmt-user-uuid: 987fcdeb-51a2-3b4c-5d6e-789012345678" \
  -d '{
    "input": "Show me the average temperature readings",
    "llm_model": "blueai",
    "datasource_uuids": ["550e8400-e29b-41d4-a716-446655440000"]
  }'
```

### Continuing a Conversation

To continue a previous conversation, include the `thread_id` from the previous response:

```bash
curl -X POST "https://api-staging.isdata.ai/usmcom/data-proxy/chat" \
  -H "Content-Type: application/json" \
  -H "x-bluemvmt-tenant-uuid: YOUR_TENANT_UUID" \
  -H "x-bluemvmt-user-uuid: YOUR_USER_UUID" \
  -d '{
    "input": "Can you break that down by month?",
    "thread_id": "thread_abc123xyz"
  }'
```

## Get Thread Messages

Retrieve all messages from a conversation thread:

```
GET /chat/messages/{thread_id}
```

### Example

```bash
curl -X GET "https://api-staging.isdata.ai/usmcom/data-proxy/chat/messages/thread_abc123xyz" \
  -H "x-bluemvmt-tenant-uuid: YOUR_TENANT_UUID" \
  -H "x-bluemvmt-user-uuid: YOUR_USER_UUID"
```
