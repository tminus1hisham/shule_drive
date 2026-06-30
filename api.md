{
  "x-generator": "NSwag v13.16.1.0 (NJsonSchema v10.7.2.0 (Newtonsoft.Json v13.0.0.0))",
  "swagger": "2.0",
  "info": {
    "title": "Shule Drive Api",
    "description": "Shule Drive Api",
    "termsOfService": "",
    "contact": {
      "name": "Stephen Kaguri",
      "url": "",
      "email": "kaguris96@gmail.com"
    },
    "license": {
      "name": "Use Under Shule Drive License Api Rules And Regulations",
      "url": "https://shuledrive.com"
    },
    "version": "v1"
  },
  "host": "staging-api.shuledrive.com",
  "schemes": [
    "https"
  ],
  "paths": {
    "/api/analytics/get/count": {
      "get": {
        "tags": [
          "Analytics"
        ],
        "operationId": "Analytics_GetCountAnalytics",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/get/all": {
      "get": {
        "tags": [
          "Attendants"
        ],
        "operationId": "Attendants_GetAllAttendants",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/create": {
      "post": {
        "tags": [
          "Attendants"
        ],
        "operationId": "Attendants_RegisterAttendant",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "registerAttendantDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterAttendantDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/get/{id}": {
      "get": {
        "tags": [
          "Attendants"
        ],
        "operationId": "Attendants_GetAttendantById",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/update/{id}": {
      "put": {
        "tags": [
          "Attendants"
        ],
        "operationId": "Attendants_UpdateAttendant",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "updateAttendantDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/Attendants"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/get/by/user": {
      "get": {
        "tags": [
          "Attendants"
        ],
        "operationId": "Attendants_GetBusByUserId",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/get/active": {
      "get": {
        "tags": [
          "Attendants"
        ],
        "operationId": "Attendants_GetAllActiveAttendant",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/delete/{id}": {
      "delete": {
        "tags": [
          "Attendants"
        ],
        "operationId": "Attendants_DeleteAttendant",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/get/deleted": {
      "get": {
        "tags": [
          "Attendants"
        ],
        "operationId": "Attendants_GetAllDeletedAttendants",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/get/inactive": {
      "get": {
        "tags": [
          "Attendants"
        ],
        "operationId": "Attendants_GetAllInactiveAttendants",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/register": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_Register",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "user",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UserRegistrationDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/login": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_Login",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "user",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UserLoginRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/enable/two/factor": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_EnableTwoFactor",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/verify/two/factor": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_VerifyTwoFactor",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/VerifyTwoFactorRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/refresh/token": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_RefreshToken",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "tokenRequest",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/TokenRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/confirm/phonenumber": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ConfirmPhoneNumber",
        "parameters": [
          {
            "type": "string",
            "name": "email",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "token",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/confirm/email": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ConfirmEmail",
        "parameters": [
          {
            "type": "string",
            "name": "email",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "token",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/forgot/password": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ForgotPassword",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "forgotPasswordRequest",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/ForgotPasswordRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/reset/password": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ResetPassword",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "resetPasswordRequest",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/ResetPasswordRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/change/password": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ChangePassword",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/ChangePasswordRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/update/profile/picture": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_UpdateProfilePicture",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "produces": [
          "text/plain",
          "application/json",
          "text/json"
        ],
        "parameters": [
          {
            "name": "formFile",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UpdateProfilePhoto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/GenericResponseModel"
            }
          }
        }
      }
    },
    "/api/auth/get/admins": {
      "get": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_GetAdmins",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/enable/admins": {
      "get": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_EnableAdmins",
        "parameters": [
          {
            "type": "string",
            "name": "id",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/disable/admins": {
      "get": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_DisableAdmins",
        "parameters": [
          {
            "type": "string",
            "name": "id",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/get/account": {
      "get": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_GetMyAccount",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/delete/{id}": {
      "delete": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_DeleteUser",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/send/notification": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_SendNotifiction",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "createFirebaseMessage",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateFirebaseMessageRequestAlt"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/send/bulk/notification": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_SendBulkNotification",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "createFirebaseMessages",
            "in": "body",
            "required": true,
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/CreateFirebaseMessageRequestAltnew"
              }
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/send/sms": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_SendMessage",
        "parameters": [
          {
            "type": "string",
            "name": "to",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "message",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/send/bulk/sms": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_SendBulkMessageSMS",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "createMessageRequest",
            "in": "body",
            "required": true,
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/CreateSMSMessageRequest"
              }
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/send/email": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_SendEmail",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "mailData",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/MailData"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/auth/send/bulk/email": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_SendBulkEmail",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "mailData",
            "in": "body",
            "required": true,
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/MailData"
              }
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/buses/get/all": {
      "get": {
        "tags": [
          "Bus"
        ],
        "operationId": "Bus_GetAllBuses",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/buses/create": {
      "post": {
        "tags": [
          "Bus"
        ],
        "operationId": "Bus_RegisterBus",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "registerBusDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterBusDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/buses/get/by/user": {
      "get": {
        "tags": [
          "Bus"
        ],
        "operationId": "Bus_GetBusByUserId",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/buses/get/{id}": {
      "get": {
        "tags": [
          "Bus"
        ],
        "operationId": "Bus_GetBusById",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/buses/update/{id}": {
      "put": {
        "tags": [
          "Bus"
        ],
        "operationId": "Bus_UpdateBus",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "updateBusDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/Buses"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/buses/get/active": {
      "get": {
        "tags": [
          "Bus"
        ],
        "operationId": "Bus_GetAllActiveBuses",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/buses/delete/{id}": {
      "delete": {
        "tags": [
          "Bus"
        ],
        "operationId": "Bus_DeleteBus",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/buses/get/deleted": {
      "get": {
        "tags": [
          "Bus"
        ],
        "operationId": "Bus_GetAllDeletedBuses",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/buses/get/inactive": {
      "get": {
        "tags": [
          "Bus"
        ],
        "operationId": "Bus_GetAllInactiveBuses",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/chats/get": {
      "get": {
        "tags": [
          "Chats"
        ],
        "operationId": "Chats_GetAllChats",
        "parameters": [
          {
            "type": "string",
            "name": "senderId",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "receiverId",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/chats/get/contacts": {
      "get": {
        "tags": [
          "Chats"
        ],
        "operationId": "Chats_GetContacts",
        "parameters": [
          {
            "type": "string",
            "name": "senderId",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/drivers/get/all": {
      "get": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_GetAllDrivers",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/drivers/get/active": {
      "get": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_GetActiveDrivers",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/drivers/get/by/school/{id}": {
      "get": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_GetAllDriversBySchoolId",
        "parameters": [
          {
            "type": "string",
            "name": "companyOrgId",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "id",
            "in": "path",
            "required": true,
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/drivers/create": {
      "post": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_CreateDriver",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "driver",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterDriverDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/drivers/get/by/user": {
      "get": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_GetDriversByUserId",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/drivers/get/by/{id}": {
      "get": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_GetDriverById",
        "produces": [
          "text/plain",
          "application/json",
          "text/json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int32",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/Drivers"
            }
          }
        }
      }
    },
    "/api/drivers/update/{id}": {
      "put": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_UpdateDriver",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "driver",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/Drivers"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/drivers/delete/{id}": {
      "delete": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_DeleteDriver",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/drivers/get/deleted": {
      "get": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_GetDeletedDrivers",
        "produces": [
          "text/plain",
          "application/json",
          "text/json"
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/Drivers"
            }
          }
        }
      }
    },
    "/api/drivers/get/inactive": {
      "get": {
        "tags": [
          "Drivers"
        ],
        "operationId": "Drivers_GetAllInActiveDrivers",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/all": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetAllGuardians",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/by/school": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetGuardians",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/create": {
      "post": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_RegisterGuardian",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "registerGuardianDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterGuardianDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/upload/file": {
      "post": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_UploadFileDetails",
        "consumes": [
          "multipart/form-data"
        ],
        "parameters": [
          {
            "type": "string",
            "name": "Schoolname",
            "in": "formData",
            "x-nullable": true
          },
          {
            "type": "file",
            "name": "formFile",
            "in": "formData",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/{id}": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetGuradiansById",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int32",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/update/{id}": {
      "put": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_UpdateGuardian",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "updateGuardiantDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/Guardians"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/student/update": {
      "put": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_UpdateStudent",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "updateStudent",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/Students"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/active": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetAllActiveGuradians",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/student/create": {
      "post": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_RegisterStudent",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "registerStudentDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterStudentDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/students": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetStudentsGuradians",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/students/by/phone": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetStudentsGuradiansByPhone",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/students/by/phone/dash": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetStudentsGuradiansByPhoneForDashboard",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/delete/{id}": {
      "delete": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_DeleteGuardian",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/student/delete/{id}": {
      "delete": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_DeleteStudent",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/deleted": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetAllDeletedGuardians",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/inactive": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetAllInactiveGuardians",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/request/delete/account": {
      "post": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_RequestDeleteAccount",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "requestDeleteAccount",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RequestDeleteAccount"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/update/child/image": {
      "post": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_UpdateChildImage",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "updateChildImageRequest",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UpdateChildImageRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/add/extended/user": {
      "post": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_AddExtendedUser",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "registerGuardianDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterGuardianDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/add/extended/user/by/admin": {
      "post": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_AddExtendedUserByAdmin",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "registerGuardianDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterGuardianDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/get/extended/guardians": {
      "get": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_GetExtendedGuardians",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/guardians/delete/extended/guardian/{id}": {
      "delete": {
        "tags": [
          "Guardians"
        ],
        "operationId": "Guardians_DeleteExtendedGuardian",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/campaigns": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetNotifictionCampaigns",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/send": {
      "post": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_CreateNotification",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "newFirebaseMessageRequest",
            "in": "body",
            "required": true,
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/NewFirebaseMessageRequest"
              }
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/all/{CampaignId}": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetNotifictionMessages",
        "parameters": [
          {
            "type": "integer",
            "name": "CampaignId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/failed/{CampaignId}": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetFailedNotifictionMessages",
        "parameters": [
          {
            "type": "integer",
            "name": "CampaignId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/success/{CampaignId}": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetSuccessNotifictionMessages",
        "parameters": [
          {
            "type": "integer",
            "name": "CampaignId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/all": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetAllNotifications",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/all/sms": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetAllSMS",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/all/emails": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetAllEmails",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/by/{phoneNumber}": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetAllNotificationsByPhone",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "path",
            "required": true,
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/email/campaigns": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetEmailCampaigns",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/notifications/campaigns": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetNotificationsCampaigns",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/email/campaigns/recipients/{campaignId}": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetEmailCampaignRecipients",
        "parameters": [
          {
            "type": "integer",
            "name": "campaignId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/notifications/campaigns/recipients/{campaignId}": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetNotificationsCampaignRecipients",
        "parameters": [
          {
            "type": "integer",
            "name": "campaignId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/notification/type": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetNotificationType",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/update/notification/type": {
      "post": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_UpdateNotificationType",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "updateNotificationTypeRequest",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UpdateNotificationTypeRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/notifications/get/notifications/by/phone": {
      "get": {
        "tags": [
          "Notifications"
        ],
        "operationId": "Notifications_GetNotificationsByPhone",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment/get": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_GetAllPaymentsPlans",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment/add/payment": {
      "post": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_AddPayment",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "paymentData",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/PaymentDataRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment/create/payment/request": {
      "post": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_AddPayment2",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "paymentRequest",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreatePaymentRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment/extend/subscription": {
      "post": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_ExtendPayment",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "extendSubscriptionModel",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/ExtendSubscriptionModel"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment/get/extensions": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_GetStudentsExtensions",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment/get/students": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_GetStudents",
        "parameters": [
          {
            "type": "string",
            "name": "orderTrackingId",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment-plans/get": {
      "get": {
        "tags": [
          "PaymentsPlan"
        ],
        "operationId": "PaymentsPlan_GetAllPaymentsPlans",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment-plans/create": {
      "post": {
        "tags": [
          "PaymentsPlan"
        ],
        "operationId": "PaymentsPlan_CreatePaymentPlan",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "registerPaymentPlan",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterPaymentPlan"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment-plans/update": {
      "put": {
        "tags": [
          "PaymentsPlan"
        ],
        "operationId": "PaymentsPlan_UpdatePaymentPlan",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "paymentsPlan",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/PaymentsPlans"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/payment-plans/delete/{id}": {
      "delete": {
        "tags": [
          "PaymentsPlan"
        ],
        "operationId": "PaymentsPlan_DeletePlan",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/attendants/get/unique/trips/from/trip": {
      "get": {
        "tags": [
          "Reports"
        ],
        "operationId": "Reports_GetTripsFromAUniqueTrip",
        "parameters": [
          {
            "type": "string",
            "name": "tripUniqueIdentity",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/get/all/roles": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetAllRoles",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/create/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_CreateRole",
        "parameters": [
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/get/all/users": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetAllUsers",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/add/user/to/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_AddUserToRole",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/get/user/roles": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetUserRoles",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/remove/user/from/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_RemoveUserFromRole",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/get/all/claims": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetAllClaims",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/add/claims/to/user": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_AddClaimsToUser",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "claimName",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "claimValue",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/remove/claim/from/user": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_RemoveClaimFromUser",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "claimName",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "claimValue",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/add/claim/to/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_AddClaimToRole",
        "parameters": [
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "claimType",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "claimValue",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/get/claims/for/role": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetClaimsForRole",
        "parameters": [
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/roles/remove/claim/from/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_RemoveClaimFromRole",
        "parameters": [
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "claimType",
            "in": "query",
            "x-nullable": true
          },
          {
            "type": "string",
            "name": "claimValue",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/routes/get/all": {
      "get": {
        "tags": [
          "Routes"
        ],
        "operationId": "Routes_GetAllRoutes",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/routes/create": {
      "post": {
        "tags": [
          "Routes"
        ],
        "operationId": "Routes_RegisterRoute",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "registerRouteDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterRouteDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/routes/get/by/user": {
      "get": {
        "tags": [
          "Routes"
        ],
        "operationId": "Routes_GetRoutesByUserId",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/routes/update/{id}": {
      "put": {
        "tags": [
          "Routes"
        ],
        "operationId": "Routes_UpdateRoute",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "_updateRoutes",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/Routes"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/routes/delete/{id}": {
      "delete": {
        "tags": [
          "Routes"
        ],
        "operationId": "Routes_DeleteRoute",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/get/all": {
      "get": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_GetAllSchools",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/create": {
      "post": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_RegisterSchool",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "registerSchoolDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/RegisterSchoolDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/get/{id}": {
      "get": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_GetSchoolById",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int32",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/get/by/user": {
      "get": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_GetSchoolsByUserId",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/update/{id}": {
      "put": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_UpdateSchool",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "updateSchoolDto",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/Schools"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/get/active": {
      "get": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_GetAllActiveSchools",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/delete/{id}": {
      "delete": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_DeleteSchool",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/get/deleted": {
      "get": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_GetAllDeletedSchools",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/get/inactive": {
      "get": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_GetAllInactiveSchools",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/schools/get/sos": {
      "get": {
        "tags": [
          "Schools"
        ],
        "operationId": "Schools_GetSOSNumber",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/get/all/master/trips": {
      "get": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_GetAllMasterTrips",
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/master/create": {
      "post": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_CreateMasterTrip",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "createMasterTrip",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateMasterTrip"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/add/student/to/master": {
      "post": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_AddStudentToMasterTrip",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "addStudentsToMasterTrip",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/AddStudentsToMasterTripRequestBody"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/activate/deactivate/master/trip": {
      "get": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_DisableMasterTrip",
        "parameters": [
          {
            "type": "integer",
            "name": "masterTripId",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/get/master/trip/students": {
      "get": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_GetMasterTripStudents",
        "parameters": [
          {
            "type": "integer",
            "name": "masterTripId",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/get/students/guardians/in/mastertrips": {
      "get": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_GetMasterTripStudentsGuardians",
        "parameters": [
          {
            "type": "integer",
            "name": "masterTripId",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/edit/master/trip": {
      "put": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_EditMasterTrip",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "masterTrip",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/MasterTrips"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/delete/master/trip": {
      "delete": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_DeleteMasterTrip",
        "parameters": [
          {
            "type": "integer",
            "name": "masterTripId",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/start": {
      "post": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_StartTrip",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "startTripRequestBody",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/StartTripRequestBody"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/delete/student/from/master/trip": {
      "delete": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_DeleteStudentFromMasterTrip",
        "parameters": [
          {
            "type": "integer",
            "name": "masterTripId",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          },
          {
            "type": "integer",
            "name": "studentId",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/get/student/active/trip": {
      "get": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_GetStudentFromActiveTrip",
        "parameters": [
          {
            "type": "integer",
            "name": "studentId",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "guardianPhone",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/pick/all": {
      "post": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_PickAllStudentsInATrip",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "pickDropAll",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/PickDropAll"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/drop/all": {
      "post": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_DropAllStudentsInATrip",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "pickDropAll",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/PickDropAll"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/get/unique/trips": {
      "get": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_GetUniqueTrips",
        "parameters": [
          {
            "type": "integer",
            "name": "masterTripId",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/get/unique/trips/from/trip": {
      "get": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_GetTripsFromAUniqueTrip",
        "parameters": [
          {
            "type": "string",
            "name": "tripUniqueIdentity",
            "in": "query",
            "x-nullable": true
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/student/not/picked": {
      "post": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_StudentNotPickedEndpoint",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "studentNotPickedRequestBody",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/StudentNotPickedRequestBody"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/create/rating": {
      "post": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_CreateRating",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "createRatingModel",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateRatingModel"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    },
    "/api/trips/pick/drop/student": {
      "post": {
        "tags": [
          "Trips"
        ],
        "operationId": "Trips_PickDropSingleStudent",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/PickSingleStudentModel"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": true,
            "description": "",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    }
  },
  "definitions": {
    "RegisterAttendantDto": {
      "type": "object",
      "required": [
        "attendantName",
        "phoneNumber",
        "schoolname",
        "licenseImage",
        "idCardImage",
        "profileImage"
      ],
      "properties": {
        "attendantName": {
          "type": "string",
          "minLength": 1
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "schoolname": {
          "type": "string",
          "minLength": 1
        },
        "licenseImage": {
          "type": "string"
        },
        "idCardImage": {
          "type": "string"
        },
        "profileImage": {
          "type": "string"
        }
      }
    },
    "Attendants": {
      "type": "object",
      "required": [
        "id",
        "attendantName",
        "phoneNumber",
        "schoolname",
        "adminUserId",
        "isAttendantActive",
        "isAttendantDeleted",
        "licenseImage",
        "idCardImage",
        "profileImage",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "attendantName": {
          "type": "string"
        },
        "phoneNumber": {
          "type": "string"
        },
        "schoolname": {
          "type": "string"
        },
        "adminUserId": {
          "type": "string"
        },
        "isAttendantActive": {
          "type": "boolean"
        },
        "isAttendantDeleted": {
          "type": "boolean"
        },
        "licenseImage": {
          "type": "string"
        },
        "idCardImage": {
          "type": "string"
        },
        "profileImage": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "UserRegistrationDto": {
      "type": "object",
      "required": [
        "companyName",
        "managerName",
        "managerPhone",
        "email",
        "physicalAddress",
        "profileType",
        "country",
        "logo",
        "password",
        "createdAt"
      ],
      "properties": {
        "companyName": {
          "type": "string",
          "minLength": 1
        },
        "managerName": {
          "type": "string"
        },
        "managerPhone": {
          "type": "string",
          "minLength": 1
        },
        "email": {
          "type": "string",
          "format": "email",
          "minLength": 1
        },
        "physicalAddress": {
          "type": "string"
        },
        "profileType": {
          "type": "string"
        },
        "country": {
          "type": "string"
        },
        "logo": {
          "type": "string"
        },
        "password": {
          "type": "string",
          "minLength": 1
        },
        "createdAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "UserLoginRequest": {
      "type": "object",
      "required": [
        "phoneNumber",
        "password",
        "firebaseToken"
      ],
      "properties": {
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "password": {
          "type": "string",
          "minLength": 1
        },
        "firebaseToken": {
          "type": "string"
        }
      }
    },
    "VerifyTwoFactorRequest": {
      "type": "object",
      "required": [
        "code",
        "email"
      ],
      "properties": {
        "code": {
          "type": "string",
          "minLength": 1
        },
        "email": {
          "type": "string"
        }
      }
    },
    "TokenRequest": {
      "type": "object",
      "required": [
        "token",
        "refreshToken"
      ],
      "properties": {
        "token": {
          "type": "string",
          "minLength": 1
        },
        "refreshToken": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "ForgotPasswordRequest": {
      "type": "object",
      "required": [
        "phoneNumber"
      ],
      "properties": {
        "phoneNumber": {
          "type": "string"
        }
      }
    },
    "ResetPasswordRequest": {
      "type": "object",
      "required": [
        "phoneNumber",
        "newPassword",
        "resetToken"
      ],
      "properties": {
        "phoneNumber": {
          "type": "string"
        },
        "newPassword": {
          "type": "string"
        },
        "resetToken": {
          "type": "string"
        }
      }
    },
    "ChangePasswordRequest": {
      "type": "object",
      "required": [
        "phoneNumber",
        "currentPassword",
        "newPassword"
      ],
      "properties": {
        "phoneNumber": {
          "type": "string"
        },
        "currentPassword": {
          "type": "string"
        },
        "newPassword": {
          "type": "string"
        }
      }
    },
    "GenericResponseModel": {
      "type": "object",
      "required": [
        "message",
        "statusCode",
        "success"
      ],
      "properties": {
        "message": {
          "type": "string"
        },
        "statusCode": {
          "type": "string"
        },
        "success": {
          "type": "boolean"
        }
      }
    },
    "UpdateProfilePhoto": {
      "type": "object",
      "required": [
        "image"
      ],
      "properties": {
        "image": {
          "type": "string"
        }
      }
    },
    "CreateFirebaseMessageRequestAlt": {
      "type": "object",
      "required": [
        "title",
        "message",
        "guardianPhoneNumber",
        "createdAt"
      ],
      "properties": {
        "title": {
          "type": "string",
          "minLength": 1
        },
        "message": {
          "type": "string",
          "minLength": 1
        },
        "guardianPhoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "createdAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "CreateFirebaseMessageRequestAltnew": {
      "type": "object",
      "required": [
        "title",
        "message",
        "guardianPhoneNumber"
      ],
      "properties": {
        "title": {
          "type": "string",
          "minLength": 1
        },
        "message": {
          "type": "string",
          "minLength": 1
        },
        "guardianPhoneNumber": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "CreateSMSMessageRequest": {
      "type": "object",
      "required": [
        "to",
        "message"
      ],
      "properties": {
        "to": {
          "type": "string",
          "minLength": 1
        },
        "message": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "MailData": {
      "type": "object",
      "required": [
        "emailTo",
        "emailSubject",
        "emailBody"
      ],
      "properties": {
        "emailTo": {
          "type": "string"
        },
        "emailSubject": {
          "type": "string"
        },
        "emailBody": {
          "type": "string"
        }
      }
    },
    "RegisterBusDto": {
      "type": "object",
      "required": [
        "numberPlate",
        "seatingCapacity",
        "createdAt"
      ],
      "properties": {
        "numberPlate": {
          "type": "string",
          "minLength": 1
        },
        "seatingCapacity": {
          "type": "integer",
          "format": "int32"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "Buses": {
      "type": "object",
      "required": [
        "id",
        "numberPlate",
        "seatingCapacity",
        "companyOrgId",
        "latitude",
        "longitude",
        "isBusActive",
        "isBusDeleted",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "numberPlate": {
          "type": "string"
        },
        "seatingCapacity": {
          "type": "integer",
          "format": "int32"
        },
        "companyOrgId": {
          "type": "string"
        },
        "latitude": {
          "type": "number",
          "format": "double"
        },
        "longitude": {
          "type": "number",
          "format": "double"
        },
        "isBusActive": {
          "type": "boolean"
        },
        "isBusDeleted": {
          "type": "boolean"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "RegisterDriverDto": {
      "type": "object",
      "required": [
        "fullname",
        "email",
        "phoneNumber",
        "address",
        "licenseImage",
        "idCardImage",
        "profileImage"
      ],
      "properties": {
        "fullname": {
          "type": "string",
          "minLength": 1
        },
        "email": {
          "type": "string"
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "address": {
          "type": "string"
        },
        "licenseImage": {
          "type": "string"
        },
        "idCardImage": {
          "type": "string"
        },
        "profileImage": {
          "type": "string"
        }
      }
    },
    "Drivers": {
      "type": "object",
      "required": [
        "id",
        "userId",
        "fullname",
        "email",
        "phoneNumber",
        "securityToken",
        "address",
        "licenseImage",
        "idCardImage",
        "profileImage",
        "companyOrgId",
        "adminUserId",
        "userType",
        "isDriverActive",
        "isDriverDeleted",
        "firebaseToken",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "userId": {
          "type": "string"
        },
        "fullname": {
          "type": "string"
        },
        "email": {
          "type": "string"
        },
        "phoneNumber": {
          "type": "string"
        },
        "securityToken": {
          "type": "string"
        },
        "address": {
          "type": "string"
        },
        "licenseImage": {
          "type": "string"
        },
        "idCardImage": {
          "type": "string"
        },
        "profileImage": {
          "type": "string"
        },
        "companyOrgId": {
          "type": "string"
        },
        "adminUserId": {
          "type": "string"
        },
        "userType": {
          "type": "string"
        },
        "isDriverActive": {
          "type": "boolean"
        },
        "isDriverDeleted": {
          "type": "boolean"
        },
        "firebaseToken": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "RegisterGuardianDto": {
      "type": "object",
      "required": [
        "fullname",
        "phoneNumber",
        "email",
        "schoolname",
        "userId"
      ],
      "properties": {
        "fullname": {
          "type": "string",
          "minLength": 1
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "email": {
          "type": "string"
        },
        "schoolname": {
          "type": "string"
        },
        "userId": {
          "type": "string"
        }
      }
    },
    "Guardians": {
      "type": "object",
      "required": [
        "id",
        "userId",
        "fullname",
        "phoneNumber",
        "securityToken",
        "email",
        "schoolname",
        "companyOrgId",
        "userType",
        "userActive",
        "isGuardianDeleted",
        "createdById",
        "editedById",
        "firebaseToken",
        "extendedUsers",
        "adminPhoneNumber",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "userId": {
          "type": "string"
        },
        "fullname": {
          "type": "string"
        },
        "phoneNumber": {
          "type": "string"
        },
        "securityToken": {
          "type": "string"
        },
        "email": {
          "type": "string"
        },
        "schoolname": {
          "type": "string"
        },
        "companyOrgId": {
          "type": "string"
        },
        "userType": {
          "type": "string"
        },
        "userActive": {
          "type": "boolean"
        },
        "isGuardianDeleted": {
          "type": "boolean"
        },
        "createdById": {
          "type": "string"
        },
        "editedById": {
          "type": "string"
        },
        "firebaseToken": {
          "type": "string"
        },
        "extendedUsers": {
          "type": "string"
        },
        "adminPhoneNumber": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "Students": {
      "type": "object",
      "required": [
        "id",
        "fullname",
        "guardianPhoneNumber",
        "studentRegNumber",
        "schoolname",
        "transportOrg",
        "classname",
        "route",
        "latitude",
        "longitude",
        "profileImage",
        "hasStudentPaid",
        "isStudentActive",
        "isStudentDeleted",
        "expirelyDate",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "fullname": {
          "type": "string"
        },
        "guardianPhoneNumber": {
          "type": "string"
        },
        "studentRegNumber": {
          "type": "string"
        },
        "schoolname": {
          "type": "string"
        },
        "transportOrg": {
          "type": "string"
        },
        "classname": {
          "type": "string"
        },
        "route": {
          "type": "string"
        },
        "latitude": {
          "type": "number",
          "format": "double"
        },
        "longitude": {
          "type": "number",
          "format": "double"
        },
        "profileImage": {
          "type": "string"
        },
        "hasStudentPaid": {
          "type": "boolean"
        },
        "isStudentActive": {
          "type": "boolean"
        },
        "isStudentDeleted": {
          "type": "boolean"
        },
        "expirelyDate": {
          "type": "string",
          "format": "date-time"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "RegisterStudentDto": {
      "type": "object",
      "required": [
        "fullname",
        "guardianPhoneNumber",
        "studentRegNumber",
        "schoolname",
        "classname",
        "route",
        "createdAt"
      ],
      "properties": {
        "fullname": {
          "type": "string",
          "minLength": 1
        },
        "guardianPhoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "studentRegNumber": {
          "type": "string"
        },
        "schoolname": {
          "type": "string",
          "minLength": 1
        },
        "classname": {
          "type": "string"
        },
        "route": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "RequestDeleteAccount": {
      "type": "object",
      "required": [
        "deleteReason",
        "phoneNumber",
        "createdAt"
      ],
      "properties": {
        "deleteReason": {
          "type": "string",
          "minLength": 1
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "createdAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "UpdateChildImageRequest": {
      "type": "object",
      "required": [
        "guardianPhoneNumber",
        "studentFullName",
        "imageUrl",
        "updatedAt"
      ],
      "properties": {
        "guardianPhoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "studentFullName": {
          "type": "string",
          "minLength": 1
        },
        "imageUrl": {
          "type": "string",
          "minLength": 1
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "NewFirebaseMessageRequest": {
      "type": "object",
      "required": [
        "message",
        "topic",
        "firebaseToken",
        "campaignId",
        "userId",
        "tripId"
      ],
      "properties": {
        "message": {
          "type": "string",
          "minLength": 1
        },
        "topic": {
          "type": "string",
          "minLength": 1
        },
        "firebaseToken": {
          "type": "string",
          "minLength": 1
        },
        "campaignId": {
          "type": "integer",
          "format": "int64"
        },
        "userId": {
          "type": "string"
        },
        "tripId": {
          "type": "string"
        }
      }
    },
    "UpdateNotificationTypeRequest": {
      "type": "object",
      "required": [
        "notificationType"
      ],
      "properties": {
        "notificationType": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "PaymentDataRequest": {
      "type": "object",
      "required": [
        "payment_method",
        "amount",
        "created_date",
        "confirmation_code",
        "order_tracking_id",
        "payment_status_description",
        "message",
        "payment_account",
        "secret_key"
      ],
      "properties": {
        "payment_method": {
          "type": "string"
        },
        "amount": {
          "type": "number",
          "format": "double"
        },
        "created_date": {
          "type": "string"
        },
        "confirmation_code": {
          "type": "string"
        },
        "order_tracking_id": {
          "type": "string"
        },
        "payment_status_description": {
          "type": "string"
        },
        "message": {
          "type": "string"
        },
        "payment_account": {
          "type": "string"
        },
        "secret_key": {
          "type": "string"
        }
      }
    },
    "CreatePaymentRequest": {
      "type": "object",
      "required": [
        "studentsCount",
        "costPerStudent",
        "duration",
        "totalCost",
        "studentIds",
        "userId",
        "orderTrackingId"
      ],
      "properties": {
        "studentsCount": {
          "type": "integer",
          "format": "int32"
        },
        "costPerStudent": {
          "type": "number",
          "format": "double"
        },
        "duration": {
          "type": "string"
        },
        "totalCost": {
          "type": "number",
          "format": "double"
        },
        "studentIds": {
          "type": "string"
        },
        "userId": {
          "type": "string"
        },
        "orderTrackingId": {
          "type": "string"
        }
      }
    },
    "ExtendSubscriptionModel": {
      "type": "object",
      "required": [
        "students",
        "dateTime"
      ],
      "properties": {
        "students": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Students"
          }
        },
        "dateTime": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "RegisterPaymentPlan": {
      "type": "object",
      "required": [
        "country",
        "countryCode",
        "currency",
        "monthlyAmountPerHead",
        "monthlySMSAmountPerHead"
      ],
      "properties": {
        "country": {
          "type": "string",
          "minLength": 1
        },
        "countryCode": {
          "type": "string",
          "minLength": 1
        },
        "currency": {
          "type": "string",
          "minLength": 1
        },
        "monthlyAmountPerHead": {
          "type": "number",
          "format": "double"
        },
        "monthlySMSAmountPerHead": {
          "type": "number",
          "format": "double"
        }
      }
    },
    "PaymentsPlans": {
      "type": "object",
      "required": [
        "id",
        "country",
        "countryCode",
        "currency",
        "monthlyAmountPerHead",
        "monthlySMSAmountPerHead",
        "adminUserId",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "country": {
          "type": "string"
        },
        "countryCode": {
          "type": "string"
        },
        "currency": {
          "type": "string"
        },
        "monthlyAmountPerHead": {
          "type": "number",
          "format": "double"
        },
        "monthlySMSAmountPerHead": {
          "type": "number",
          "format": "double"
        },
        "adminUserId": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "RegisterRouteDto": {
      "type": "object",
      "required": [
        "schoolname",
        "routeName"
      ],
      "properties": {
        "schoolname": {
          "type": "string",
          "minLength": 1
        },
        "routeName": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "Routes": {
      "type": "object",
      "required": [
        "id",
        "routeName",
        "schoolName",
        "adminUserId",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "routeName": {
          "type": "string"
        },
        "schoolName": {
          "type": "string"
        },
        "adminUserId": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "RegisterSchoolDto": {
      "type": "object",
      "required": [
        "schoolname",
        "contactPerson",
        "phoneNumber",
        "address",
        "logo"
      ],
      "properties": {
        "schoolname": {
          "type": "string",
          "minLength": 1
        },
        "contactPerson": {
          "type": "string",
          "minLength": 1
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "address": {
          "type": "string",
          "minLength": 1
        },
        "logo": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "Schools": {
      "type": "object",
      "required": [
        "id",
        "schoolname",
        "contactPerson",
        "phoneNumber",
        "address",
        "logo",
        "adminUserId",
        "sosNumber",
        "isSchoolActive",
        "isSchoolDeleted",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "schoolname": {
          "type": "string"
        },
        "contactPerson": {
          "type": "string"
        },
        "phoneNumber": {
          "type": "string"
        },
        "address": {
          "type": "string"
        },
        "logo": {
          "type": "string"
        },
        "adminUserId": {
          "type": "string"
        },
        "sosNumber": {
          "type": "string"
        },
        "isSchoolActive": {
          "type": "boolean"
        },
        "isSchoolDeleted": {
          "type": "boolean"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "CreateMasterTrip": {
      "type": "object",
      "required": [
        "tripName",
        "tripTime",
        "tripDirection",
        "route",
        "numberPlate",
        "attendantName",
        "driverName",
        "createdAt"
      ],
      "properties": {
        "tripName": {
          "type": "string",
          "minLength": 1
        },
        "tripTime": {
          "type": "string"
        },
        "tripDirection": {
          "type": "string"
        },
        "route": {
          "type": "string",
          "minLength": 1
        },
        "numberPlate": {
          "type": "string",
          "minLength": 1
        },
        "attendantName": {
          "type": "string"
        },
        "driverName": {
          "type": "string",
          "minLength": 1
        },
        "createdAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "AddStudentsToMasterTripRequestBody": {
      "type": "object",
      "required": [
        "masterTripId",
        "fullname",
        "studentRegNumber",
        "studentId",
        "guardianPhoneNumber",
        "schoolname",
        "classname",
        "route",
        "latitude",
        "longitude",
        "createdAt"
      ],
      "properties": {
        "masterTripId": {
          "type": "integer",
          "format": "int64"
        },
        "fullname": {
          "type": "string",
          "minLength": 1
        },
        "studentRegNumber": {
          "type": "string"
        },
        "studentId": {
          "type": "integer",
          "format": "int64"
        },
        "guardianPhoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "schoolname": {
          "type": "string",
          "minLength": 1
        },
        "classname": {
          "type": "string"
        },
        "route": {
          "type": "string",
          "minLength": 1
        },
        "latitude": {
          "type": "number",
          "format": "double"
        },
        "longitude": {
          "type": "number",
          "format": "double"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "MasterTrips": {
      "type": "object",
      "required": [
        "id",
        "tripName",
        "tripTime",
        "tripType",
        "tripDirection",
        "route",
        "createdBy",
        "schoolname",
        "adminUserId",
        "isTripActive",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "tripName": {
          "type": "string"
        },
        "tripTime": {
          "type": "string"
        },
        "tripType": {
          "type": "string"
        },
        "tripDirection": {
          "type": "string"
        },
        "route": {
          "type": "string"
        },
        "createdBy": {
          "type": "string"
        },
        "schoolname": {
          "type": "string"
        },
        "adminUserId": {
          "type": "string"
        },
        "isTripActive": {
          "type": "boolean"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "StartTripRequestBody": {
      "type": "object",
      "required": [
        "masterTripId",
        "tripName",
        "route",
        "driverName",
        "driverPhoneNumber",
        "numberPlate",
        "attendantName",
        "attendantPhoneNumber",
        "attendantProfileImage",
        "createdAt"
      ],
      "properties": {
        "masterTripId": {
          "type": "integer",
          "format": "int64"
        },
        "tripName": {
          "type": "string",
          "minLength": 1
        },
        "route": {
          "type": "string",
          "minLength": 1
        },
        "driverName": {
          "type": "string",
          "minLength": 1
        },
        "driverPhoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "numberPlate": {
          "type": "string",
          "minLength": 1
        },
        "attendantName": {
          "type": "string"
        },
        "attendantPhoneNumber": {
          "type": "string"
        },
        "attendantProfileImage": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "PickDropAll": {
      "type": "object",
      "required": [
        "uniqueTripIdentity",
        "latitude",
        "longitude",
        "isDroppingAll",
        "updatedAt"
      ],
      "properties": {
        "uniqueTripIdentity": {
          "type": "string",
          "minLength": 1
        },
        "latitude": {
          "type": "number",
          "format": "double"
        },
        "longitude": {
          "type": "number",
          "format": "double"
        },
        "isDroppingAll": {
          "type": "boolean"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "StudentNotPickedRequestBody": {
      "type": "object",
      "required": [
        "tripUniqueIdentity",
        "studentId",
        "reason",
        "updatedAt"
      ],
      "properties": {
        "tripUniqueIdentity": {
          "type": "string",
          "minLength": 1
        },
        "studentId": {
          "type": "integer",
          "format": "int64"
        },
        "reason": {
          "type": "string"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "CreateRatingModel": {
      "type": "object",
      "required": [
        "phoneNumber",
        "rating",
        "tripUniqueIdentity",
        "updatedAt"
      ],
      "properties": {
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "rating": {
          "type": "number",
          "format": "double"
        },
        "tripUniqueIdentity": {
          "type": "string",
          "minLength": 1
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        }
      }
    },
    "PickSingleStudentModel": {
      "type": "object",
      "required": [
        "uniqueTripIdentity",
        "studentReg",
        "guardianPhoneNumber",
        "numberPlate",
        "action",
        "latitude",
        "longitude"
      ],
      "properties": {
        "uniqueTripIdentity": {
          "type": "string",
          "minLength": 1
        },
        "studentReg": {
          "type": "string",
          "minLength": 1
        },
        "guardianPhoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "numberPlate": {
          "type": "string",
          "minLength": 1
        },
        "action": {
          "type": "string",
          "minLength": 1
        },
        "latitude": {
          "type": "number",
          "format": "double"
        },
        "longitude": {
          "type": "number",
          "format": "double"
        }
      }
    }
  },
  "securityDefinitions": {
    "Bearer": {
      "type": "apiKey",
      "name": "Authorization",
      "in": "header"
    }
  },
  "security": [
    {
      "Bearer": []
    }
  ]
}