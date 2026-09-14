CREATE TYPE "ConversationMode" AS ENUM ('AI', 'HUMAN');

ALTER TABLE "Shop"
  ADD COLUMN "whatsappPhoneNumberId" TEXT,
  ADD COLUMN "whatsappBusinessAccountId" TEXT,
  ADD COLUMN "whatsappDisplayPhone" TEXT,
  ADD COLUMN "botEnabled" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "botWelcomeMessage" TEXT,
  ADD COLUMN "botSystemPrompt" TEXT,
  ADD COLUMN "handoffKeywords" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

ALTER TABLE "WhatsappConversation"
  ADD COLUMN "mode" "ConversationMode" NOT NULL DEFAULT 'AI',
  ADD COLUMN "assignedUserId" TEXT;

ALTER TABLE "WhatsappMessage"
  ADD COLUMN "providerMessageId" TEXT;

CREATE TABLE "WhatsappEvent" (
  "id" TEXT NOT NULL,
  "shopId" TEXT NOT NULL,
  "providerMessageId" TEXT NOT NULL,
  "eventType" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "WhatsappEvent_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "WhatsappEvent_providerMessageId_key" UNIQUE ("providerMessageId"),
  CONSTRAINT "WhatsappEvent_shopId_fkey" FOREIGN KEY ("shopId") REFERENCES "Shop"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "WhatsappMessage_shopId_providerMessageId_key" ON "WhatsappMessage"("shopId", "providerMessageId");
CREATE INDEX "Shop_whatsappPhoneNumberId_idx" ON "Shop"("whatsappPhoneNumberId");
CREATE INDEX "WhatsappConversation_shopId_mode_idx" ON "WhatsappConversation"("shopId", "mode");
CREATE INDEX "WhatsappEvent_shopId_createdAt_idx" ON "WhatsappEvent"("shopId", "createdAt");
