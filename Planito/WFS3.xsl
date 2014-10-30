<!-- <?xml version="1.0"?> -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:gml="http://www.opengis.net/gml" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:topp="http://www.openplans.org/topp" version="1.0">
    <xsl:output method="xml" indent="no"/>

    <xsl:template match="/">
        <features>
            <xsl:apply-templates select="//gml:featureMembers/topp:*"/>
        </features>
    </xsl:template>

    <xsl:template match="topp:*">
        <pm>
            <xsl:attribute name="c">
                <xsl:value-of select="normalize-space(topp:latitude)" /><xsl:text>,</xsl:text><xsl:value-of select="normalize-space(topp:longitude)" />
            </xsl:attribute>

            <xsl:attribute name="s">
                <xsl:value-of select="name()" />
            </xsl:attribute>

            <l>
                <xsl:value-of select="normalize-space(topp:full_name_nd)" />
            </l>
        </pm>
    </xsl:template>
</xsl:stylesheet> 